import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants/app_constants.dart';
import '../models/audio_state.dart';
import 'runtime_config_service.dart';
import 'shared_prefs_service.dart';

enum TtsState { playing, stopped, paused, continued }

/// What [TtsService.setLanguage] actually did. Replaces the previous
/// `String?` return contract, which conflated "voice unavailable" with
/// "engine kept the previous voice, which happens to equal what the
/// caller asked for" — letting SnackBars lie about the language being
/// spoken.
enum SetLanguageOutcome {
  /// The requested voice was found and is now active.
  ok,

  /// The voice isn't installed on this device. The engine kept its
  /// previous voice (which may or may not match the requested code).
  /// Callers should warn the user; the engine's active voice is
  /// whatever it was before this call.
  voiceUnavailable,

  /// The requested code isn't in our supported map at all. Engine
  /// state is unchanged. Callers should treat this as a programming
  /// error or guard against unsupported codes up-front.
  unsupportedCode,
}

/// What [TtsService.speak] decided to actually read out. Truncation is
/// exposed as a first-class field so callers can prompt the user to
/// upgrade instead of silently playing a clipped preview.
class TtsSpeakResult {
  const TtsSpeakResult({required this.wasTruncated});
  final bool wasTruncated;
}

/// Internal pair returned by the sentence-boundary chunker: the chunk of
/// text the engine will read, and whether we had to cut.
class TtsChunk {
  const TtsChunk({required this.text, required this.wasCut});
  final String text;
  final bool wasCut;
}

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  TtsState _state = TtsState.stopped;
  String _currentLanguage = 'en-US';
  bool _isPremium = false;
  int _maxDurationSeconds = AppConstants.freeAudioMaxSeconds;

  TtsState get state => _state;
  String get currentLanguage => _currentLanguage;
  bool get isPlaying => _state == TtsState.playing;
  bool get isPremium => _isPremium;

  // --- Session (generation) token --------------------------------------
  //
  // Customer-facing bug: pause / site-change could leave the previous
  // session's callbacks (progress, completion, error) wired into the
  // cubit *after* a new session had already started. The OLD callback
  // would then fire for the NEW utterance and overwrite the new state
  // — the bar would jump back to the old text's position, or the
  // completion handler would recursively call playAudio on the old
  // (now-gone) site, freezing the new bar.
  //
  // A monotonic session token fixes this without scattered boolean
  // flags. Every "I have a new listener" call (startReportingPosition,
  // setOnCompletion) captures the *current* token at registration
  // time. When the callback fires it compares its captured token to
  // the live token — if they differ, the session has been invalidated
  // (stop, pause, new speak, dispose) and the callback bails.
  //
  // The token is also bumped by `invalidateSession()`, which is the
  // single entry point the cubit uses to say "previous session is dead,
  // forget everything you know about it." Bumping the token here is
  // what guarantees that a stale callback cannot race past the
  // stop+reporter-clear sequence.
  int _sessionToken = 0;

  /// Current session token. Bumped on every state transition that
  /// invalidates in-flight callbacks (stop, pause, new speak, dispose).
  /// Callers that want to detect a callback that has been superseded
  /// call [beginSession] at registration time and compare the returned
  /// value to this getter when the callback fires.
  int get currentSessionToken => _sessionToken;

  /// Start a new session and return the token that callbacks should
  /// capture. Call this once at the top of every play / resume / pause
  /// branch — the returned token is the one the captured callbacks
  /// will compare against.
  int beginSession() {
    _sessionToken++;
    return _sessionToken;
  }

  /// Invalidate the current session. Bumps the token, clears the
  /// active reporter, the completion callback, the error callback, the
  /// resume point, and the start-time stamp. The engine itself is
  /// stopped asynchronously. After this call, no previous callback
  /// can modify shared state.
  ///
  /// This is the single entry point the cubit should use to say
  /// "the previous audio session is dead." Do not call
  /// [stopReportingPosition] + [setOnCompletion] + [stop] piecemeal —
  /// that leaves room for a stale callback to slip between the
  /// teardown steps.
  void invalidateSession() {
    _sessionToken++;
    _activeFingerprint = null;
    _activeSpokenText = null;
    _activeOnPosition = null;
    _activeResumeBaseline = 0;
    _lastObservedOffset = 0;
    _lastObservationMs = 0;
    _firstObservationSinceStart = true;
    _onCompletion = null;
    _onError = null;
    _speakStartMs = null;
    // NB: we deliberately do NOT clear `_lastOffsetForPause` /
    // `_lastSpokenTextForPause` / `_lastFingerprintForPause` here.
    // `pauseForRestart` invokes `invalidateSession` BEFORE reading the
    // snapshot, so the snapshot must survive this call. The snapshot
    // is cleared by `pauseForRestart` itself after capture, and by the
    // next `startReportingPosition` (which re-seeds it for the new
    // chunk).
  }

  // --- Progress reporting (replaces the cubit's local Timer) ----------
  //
  // flutter_tts's setProgressHandler fires (text, start, end, word) as
  // the native engine progresses. start/end are CHARACTER OFFSETS into
  // the text we handed to speak() — not ms, not word indices. There is
  // no per-call cancellation or "I'm done" event beyond the existing
  // completion/cancel/error handlers; the cubit clamps against its own
  // AudioState.duration to detect end-of-chunk.

  /// Fingerprint of the chunk we last asked to report progress for. Used
  /// to ignore stale callbacks that arrive after a stopAudio / speak()
  /// cycle swap. Cheap to compute, good enough to disambiguate.
  String? _activeFingerprint;
  ValueChanged<Duration>? _activeOnPosition;

  /// Snapshot of the chunk the engine is speaking, paired with the
  /// fingerprint. Pause-and-restart on Android needs the original chunk
  /// text (not just the offset) so it can re-speak the suffix.
  String? _activeSpokenText;

  /// Optional sink for native-engine errors (network failures, missing
  /// voices, plugin exceptions). The cubit routes these through the
  /// localization SnackBar channel so the user sees a real message
  /// instead of a silent dead bar. Set once via [setOnError]; may be
  /// null when no listener is attached (e.g. in unit tests).
  ValueChanged<String>? _onError;

  /// Install a callback to receive native-engine error messages. Replaces
  /// any previously-installed callback; pass null to detach.
  ///
  /// The callback is wrapped so its invocation is dropped if the session
  /// has been invalidated since this call (e.g. the user navigated
  /// between sites, paused, or stopped). This is the single mechanism
  /// that prevents a stale error event from leaking into the new
  /// site's UI.
  void setOnError(ValueChanged<String>? onError) {
    if (onError == null) {
      _onError = null;
      return;
    }
    final myToken = _sessionToken;
    _onError = (msg) {
      if (myToken != _sessionToken) return;
      onError(msg);
    };
  }

  // --- Real-duration measurement (Fix 1) ------------------------------
  //
  // flutter_tts has no API to query "how long will this text take?".
  // We measure the actual elapsed time: record a wall-clock timestamp
  // when speak() is called, then compute (now - startTime) when the
  // engine's completion handler fires. The cubit receives this via the
  // _onCompletion callback and updates AudioState.duration so every
  // subsequent replay shows the exact real MM:SS from the very first
  // loop iteration.

  /// Wall-clock time at which the most recent speak() call was issued.
  /// Null when nothing is playing (cleared on stop/cancel).
  int? _speakStartMs;

  /// Callback invoked when the engine completes an utterance naturally
  /// (not on stop() or cancel()). Receives the actual measured Duration
  /// of the completed utterance so the cubit can update AudioState and
  /// trigger infinite-loop replay for premium users.
  ///
  /// Set via [setOnCompletion]; may be null when not attached (tests).
  ValueChanged<Duration>? _onCompletion;

  /// Install a completion callback. Pass null to detach.
  ///
  /// The callback is wrapped so its invocation is dropped if the session
  /// has moved on since this call — without this, a stale completion
  /// from a previous utterance could fire *after* a new `playAudio` has
  /// registered its own callback, recursively call `playAudio` for the
  /// old site, and freeze the new bar.
  void setOnCompletion(ValueChanged<Duration>? onCompletion) {
    if (onCompletion == null) {
      _onCompletion = null;
      return;
    }
    final myToken = _sessionToken;
    _onCompletion = (realDuration) {
      if (myToken != _sessionToken) return;
      onCompletion(realDuration);
    };
  }

  // --------------------------------------------------------------------

  /// Char offset added to every observed progress event. Set non-zero on
  /// Android resume so the visible position jumps forward to where the
  /// engine actually picks up, instead of resetting to 0.
  int _activeResumeBaseline = 0;

  /// Self-calibrating chars-per-ms. Start at the population estimate
  /// (12.5 chars/sec → 80 ms/char) and refine as real callbacks arrive.
  double _msPerChar = 80;

  /// (lastObservedCharOffset, timestampMs) — used to compute the running
  /// chars/sec from observed engine progress. Reset on every
  /// `startReportingPosition`.
  int _lastObservedOffset = 0;
  int _lastObservationMs = 0;

  Future<void> init({bool isPremium = false}) async {
    _isPremium = isPremium;
    _updateMaxDuration();

    await _flutterTts.setSharedInstance(true);
    // Apply the user's persisted playback-speed preference at startup so
    // their choice survives app restarts. Falls back to 1.0x multiplier
    // when SharedPrefsService hasn't been initialised yet (e.g. in tests).
    _currentSpeedMultiplier = _safeReadPlaybackSpeedMultiplier();
    await _flutterTts.setSpeechRate(_engineRateForMultiplier(_currentSpeedMultiplier));
    await _flutterTts.setPitch(AppConstants.defaultPitch);
    await _flutterTts.setVolume(AppConstants.defaultVolume);

    _flutterTts.setCompletionHandler(() {
      _state = TtsState.stopped;
      // Measure how long the utterance actually took and report it.
      // We only fire _onCompletion when the engine reached the natural
      // end of text — not on stop() or cancel() — so the cubit can
      // safely trigger replay without a double-fire race. The
      // session-token gate inside setOnCompletion is the second line
      // of defense against a stop()/new-play() race that could let
      // a stale completion fire into a new session.
      final startMs = _speakStartMs;
      _speakStartMs = null;
      if (startMs != null) {
        final realDuration = Duration(
          milliseconds: DateTime.now().millisecondsSinceEpoch - startMs,
        );
        _onCompletion?.call(realDuration);
      }
    });

    _flutterTts.setCancelHandler(() {
      _state = TtsState.stopped;
      // Cancel is triggered by stop() or a new speak() — do NOT fire
      // the completion callback here; we don't want a replay triggered
      // by a user-initiated stop. We do NOT invalidate the session
      // here — the cubit owns that decision (see stop()/pause()/
      // playAudio() in SiteDetailCubit). InvalidateSession() would
      // observe in-progress teardown and could double-bump the token,
      // which is harmless but useless.
      _speakStartMs = null;
    });

    _flutterTts.setErrorHandler((msg) {
      _state = TtsState.stopped;
      // Forward native-engine errors to a registered listener. On
      // Android the most common failure mode is "no network" for
      // Google TTS voices — previously the user just saw a dead bar.
      // Empty messages (some platforms fire a blank error on cancel)
      // are suppressed so the cubit doesn't show an empty SnackBar.
      // The plugin types this parameter as dynamic; coerce defensively.
      // The session-token gate inside setOnError stops a stale error
      // from a previous utterance leaking into the new site's UI.
      final raw = msg is String ? msg : '';
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) {
        _onError?.call(trimmed);
      }
    });

    // Install once; the handler routes through the *_active* fields
    // which get swapped per-speak().
    _flutterTts.setProgressHandler(_onProgress);

    await _setDefaultLanguage();
  }

  Future<void> _setDefaultLanguage() async {
    final languages =
        (await _flutterTts.getLanguages as List?)?.cast<String>() ?? [];
    if (languages.contains('en-US')) {
      await _flutterTts.setLanguage('en-US');
      _currentLanguage = 'en-US';
    }
  }

  double _currentSpeedMultiplier = 1.0;

  /// Current playback rate multiplier (e.g. 0.75, 1.0, 1.25, 1.5).
  double get currentSpeedMultiplier => _currentSpeedMultiplier;

  /// Translate a user-facing playback speed multiplier (0.75, 1.0, 1.25, 1.5)
  /// into the native engine speech rate [0.0, 1.0].
  double _engineRateForMultiplier(double multiplier) {
    return (AppConstants.defaultSpeechRate * multiplier).clamp(0.0, 1.0);
  }

  void setPremium(bool isPremium) {
    _isPremium = isPremium;
    _updateMaxDuration();
  }

  /// Apply a new speech rate multiplier (e.g. 0.75, 1.0, 1.25, 1.5) to the
  /// engine immediately. Called by the settings screen when the user changes
  /// the playback-speed selector so subsequent speak() calls pick up the new
  /// rate without restarting the app.
  Future<void> applyPlaybackSpeed(double speedMultiplier) async {
    _currentSpeedMultiplier = speedMultiplier;
    await _flutterTts.setSpeechRate(_engineRateForMultiplier(speedMultiplier));
  }

  /// Read the persisted playback speed multiplier from SharedPreferences.
  /// Defaults to 1.0 (1x normal playback) if not set or service is not ready.
  static double _safeReadPlaybackSpeedMultiplier() {
    try {
      final raw = SharedPrefsService.instance.playbackSpeed;
      return raw.clamp(0.25, 3.0);
    } catch (_) {
      return 1.0;
    }
  }

  /// Update the free-tier narration cap at runtime. Mirrors [setPremium] —
  /// call after the admin changes the value through [RuntimeConfigCubit] so
  /// the next `speak()` reflects the new budget without an app restart.
  /// Restart also picks up the change because [_updateMaxDuration] re-reads
  /// from [RuntimeConfigService] on every call.
  void setFreeAudioMaxSeconds(int seconds) {
    _updateMaxDuration();
  }

  void _updateMaxDuration() {
    // Re-read on every update so a runtime change takes effect even if a
    // caller forgets to invoke [setFreeAudioMaxSeconds] explicitly.
    // Premium users get unlimited playback (0 = no cap).
    _maxDurationSeconds =
        _isPremium ? 0 : RuntimeConfigService.instance.freeAudioMaxSeconds;
  }

  /// Switch the TTS voice to the locale matching [languageCode].
  ///
  /// Returns a [SetLanguageOutcome] describing what happened. Callers
  /// should warn the user on [SetLanguageOutcome.voiceUnavailable] —
  /// the engine keeps its previous voice, which may or may not match
  /// the requested code. To find the engine's active voice, read
  /// [currentLanguage] after the call.
  ///
  /// [SetLanguageOutcome.unsupportedCode] means the code isn't in our
  /// supported map at all; the engine is untouched.
  Future<SetLanguageOutcome> setLanguage(String languageCode) async {
    const languageMap = {
      'en': 'en-US',
      'sw': 'sw-KE',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'ar': 'ar-SA',
      'it': 'it-IT',
      'es': 'es-ES',
    };

    final ttsLanguage = languageMap[languageCode];
    if (ttsLanguage == null) {
      return SetLanguageOutcome.unsupportedCode;
    }

    final availableLanguages =
        (await _flutterTts.getLanguages as List?)?.cast<String>() ?? [];
    if (!availableLanguages.contains(ttsLanguage)) {
      // Voice not installed. Don't switch; the engine keeps its previous
      // (or default) voice. Caller can read `currentLanguage` to find out
      // what's actually playing.
      return SetLanguageOutcome.voiceUnavailable;
    }

    await _flutterTts.setLanguage(ttsLanguage);
    _currentLanguage = ttsLanguage;
    return SetLanguageOutcome.ok;
  }

  Future<List<String>> getAvailableLanguages() async {
    final languages =
        (await _flutterTts.getLanguages as List?)?.cast<String>() ?? [];
    final supported = <String>[];

    final languageMap = {
      'en-US': 'en',
      'sw-KE': 'sw',
      'fr-FR': 'fr',
      'de-DE': 'de',
      'ar-SA': 'ar',
      'it-IT': 'it',
      'es-ES': 'es',
    };

    for (final lang in languages) {
      if (languageMap.containsKey(lang)) {
        supported.add(languageMap[lang]!);
      }
    }

    return supported.isEmpty ? ['en', 'sw'] : supported;
  }

  /// Result of a [speak] call. [wasTruncated] is true for free-tier users
  /// whose narration hit the per-session time cap; the audio stopped at a
  /// sentence boundary and the UI should prompt the user to upgrade.
  Future<TtsSpeakResult> speak(
    String text, {
    String? languageCode,
    TtsChunk? precomputedChunk,
  }) async {
    if (text.isEmpty) {
      return const TtsSpeakResult(wasTruncated: false);
    }

    // Fix 3: Always re-apply the engine language before every speak().
    //
    // After flutter_tts.stop() some Android engine builds silently
    // release the active voice. Subsequent speak() calls produce no
    // audio because the engine has no voice handle — even though
    // _currentLanguage still holds the correct BCP-47 tag. Calling
    // setLanguage() unconditionally here (bypassing the equality guard
    // inside setLanguage() itself) restores the engine's voice handle
    // before every new utterance, at negligible cost.
    final langToApply = languageCode ?? _currentLanguage;
    await _forceApplyLanguage(langToApply);

    // If the caller already computed a chunk (via [previewChunkFor]),
    // speak it verbatim. This guarantees the engine is speaking the
    // exact text the progress reporter's fingerprint was built from —
    // crucially, it prevents a premium flip between previewChunkFor
    // and speak from producing a different chunk at the engine layer
    // than the one the reporter is tracking.
    final resolvedChunk = precomputedChunk ?? _speakChunk(text);
    // Fix 1: Stamp the wall-clock time so the completion handler can
    // compute the real utterance duration.
    _speakStartMs = DateTime.now().millisecondsSinceEpoch;
    await _flutterTts.speak(resolvedChunk.text);
    _state = TtsState.playing;
    return TtsSpeakResult(wasTruncated: resolvedChunk.wasCut);
  }

  /// Apply [languageCode] to the engine unconditionally, bypassing the
  /// availability guard in [setLanguage]. Used internally by [speak] to
  /// restore the engine's voice handle after a stop/cancel cycle without
  /// an extra async availability query on every utterance.
  Future<void> _forceApplyLanguage(String languageCode) async {
    const languageMap = {
      'en': 'en-US',
      'sw': 'sw-KE',
      'fr': 'fr-FR',
      'de': 'de-DE',
      'ar': 'ar-SA',
      'it': 'it-IT',
      'es': 'es-ES',
    };
    final ttsLang = languageMap[languageCode] ?? _currentLanguage;
    await _flutterTts.setLanguage(ttsLang);
    _currentLanguage = ttsLang;
    // Re-apply speech rate because changing language/voice on native engines
    // (especially Android TextToSpeech) resets the rate back to default.
    await _flutterTts.setSpeechRate(_engineRateForMultiplier(_currentSpeedMultiplier));
  }

  /// Compute the chunk the engine will speak for [text] under the
  /// current premium/maxDuration settings. Extracted from [speak] so
  /// it can be called once and shared between the cubit (which uses
  /// the result for its fingerprint) and [speak] (which uses it for
  /// the actual engine call).
  TtsChunk _speakChunk(String text) {
    if (_isPremium) {
      return TtsChunk(text: text, wasCut: false);
    }
    return _chunkForDuration(text, _maxDurationSeconds);
  }

  /// Sentence-boundary chunker. Walks the input looking for terminators
  /// (`.`, `!`, `?`, Arabic `؟`, Arabic `،` clause separator) and returns
  /// the largest concatenation of whole sentences whose estimated speech
  /// time is *at least* [maxSeconds] — never shorter. The previous
  /// implementation cut at the last terminator before the budget, which
  /// produced previews of 6–25 s on passages whose first sentence was
  /// short, betraying the "30-second preview" marketing copy.
  ///
  /// Algorithm:
  ///   1. If the whole text fits in the budget, return verbatim.
  ///   2. Otherwise collect every terminator index in the text.
  ///   3. Pick the first terminator whose index is at-or-after the
  ///      character budget (proportional to the word budget).
  ///   4. If no terminator is past the budget, fall back to the LAST
  ///      terminator (still better than the worst-case first-word).
  ///   5. If there are no terminators at all, return the full text
  ///      and let the engine stop be the safety net.
  TtsChunk _chunkForDuration(String text, int maxSeconds) {
    const wordsPerSecond = 2.5;
    final maxWords = (maxSeconds * wordsPerSecond).round();
    final allWords = text.trim().split(RegExp(r'\s+'));
    if (allWords.length <= maxWords) {
      return TtsChunk(text: text, wasCut: false);
    }

    // Collect every sentence-terminator index (position immediately
    // AFTER the terminator, so the cut includes the terminator itself).
    final terminatorIndices = <int>[];
    for (int i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '.' || c == '!' || c == '?' || c == '؟' || c == '،') {
        terminatorIndices.add(i + 1);
      }
    }

    // No terminator at all — return the full text and let the engine
    // stop be the safety net (matches existing behaviour).
    if (terminatorIndices.isEmpty) {
      return TtsChunk(text: text, wasCut: false);
    }

    // Approximate the character budget proportionally to the word budget.
    final budgetChars = ((maxWords / allWords.length) * text.length)
        .round()
        .clamp(0, text.length);

    // Pick the first terminator at-or-after the budget. The preview is
    // guaranteed to be at least the advertised length on inputs that
    // contain sentence boundaries past the budget.
    int cutIndex = -1;
    for (final idx in terminatorIndices) {
      if (idx >= budgetChars) {
        cutIndex = idx;
        break;
      }
    }

    // No terminator past the budget — fall back to the last one we
    // have. This is the best we can do without slicing mid-word.
    cutIndex = cutIndex == -1 ? terminatorIndices.last : cutIndex;

    final truncated = text.substring(0, cutIndex).trimRight();
    return TtsChunk(text: truncated, wasCut: true);
  }

  Future<void> stop() async {
    // Clear the start-time stamp before stop() so the cancel handler
    // (which flutter_tts fires on stop()) does not accidentally compute
    // a bogus duration and trigger replay.
    _speakStartMs = null;
    // Invalidate the session BEFORE the engine call so any
    // completion callbacks that race the await are dropped by the
    // token guard. The cancel handler installs session teardown
    // steps (state -> stopped), but the session token is the
    // single source of truth for "is this callback still alive".
    invalidateSession();
    await _flutterTts.stop();
    _state = TtsState.stopped;
  }

  Future<void> pause() async {
    await _flutterTts.pause();
    _state = TtsState.paused;
  }

  Future<void> resume() async {
    // flutter_tts v4.x has no resume() method — the plugin's pause() calls
    // AVSpeechSynthesizer.pauseSpeaking() natively but there is no
    // corresponding unpause channel method. Both iOS and Android resume
    // by re-speaking the suffix via resumeFrom() / resumeAudio().
    // This method now only updates the internal state flag; the actual
    // audio is re-started by the cubit calling resumeFrom().
    _state = TtsState.continued;
  }

  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  int? getMaxDuration() {
    return _isPremium ? null : _maxDurationSeconds;
  }

  /// Estimate how long [text] will take to speak at the default speech
  /// rate (2.5 words/sec). Used as the initial bar duration before the
  /// engine's self-calibration kicks in. The returned value matches what
  /// the chunker uses, so the bar never shows longer than the chunk.
  ///
  /// For free-tier users this caps at [_maxDurationSeconds] (just like
  /// the chunker). For premium users the full text is estimated.
  Duration estimateDuration(String text) {
    if (text.trim().isEmpty) return Duration.zero;
    if (_isPremium) {
      return _durationForText(text);
    }
    // Free-tier cap: never estimate longer than the preview budget.
    final uncapped = _durationForText(text);
    final cap = Duration(seconds: _maxDurationSeconds);
    return uncapped < cap ? uncapped : cap;
  }

  /// Convert [text] word-count to a Duration at 2.5 words/sec.
  Duration _durationForText(String text) {
    const wordsPerSecond = 2.5;
    final wordCount = text.trim().split(RegExp(r'\s+')).length;
    final seconds = (wordCount / wordsPerSecond).ceil().clamp(1, 3600);
    return Duration(seconds: seconds);
  }

  /// Sentence-bounded preview chunk for the active free-tier settings.
  /// Exposed so [SiteDetailCubit] can hand the exact same string to
  /// [startReportingPosition] (the engine's progress callback uses the
  /// spoken text as its source of offsets, so the chunk we report
  /// progress for must equal the chunk the engine is speaking).
  ///
  /// Premium users get the full text back as-is. Without this guard,
  /// `_chunkForDuration` would compute `maxWords = 0` (since
  /// `_maxDurationSeconds` is 0 for premium) and always truncate on
  /// the first word — the reporter's fingerprint would then mismatch
  /// the full text the engine is actually speaking, and every
  /// progress callback would be filtered as stale.
  TtsChunk previewChunkFor(String text) {
    if (_isPremium) {
      return TtsChunk(text: text, wasCut: false);
    }
    return _chunkForDuration(text, _maxDurationSeconds);
  }

  // --- Progress-reporting driver --------------------------------------

  /// Begin forwarding TTS-engine progress into [onPosition]. [spokenText]
  /// must be the exact string previously passed to [speak] — the handler
  /// uses a fingerprint of it to ignore stale callbacks that arrive
  /// after a quick stopAudio / playAudio cycle.
  ///
  /// [budget] is the chunk's expected total Duration; the cubit clamps
  /// against its own AudioState.duration, so this is informational.
  ///
  /// [resumeBaseline] is non-zero when this reporter is being installed
  /// as part of an Android resume — the engine is speaking the suffix
  /// of [spokenText], so every emitted Duration is offset by the chars
  /// that came before the resume point. The cubit uses this to keep the
  /// visible progress bar in sync without snapping back to zero.
  void startReportingPosition(
    String spokenText, {
    required ValueChanged<Duration> onPosition,
    required Duration budget,
    int resumeBaseline = 0,
  }) {
    _activeFingerprint = _fingerprint(spokenText);
    _activeSpokenText = spokenText;
    _activeResumeBaseline = resumeBaseline;
    // Stamp the time at which the reporter was installed. The
    // wall-clock fallback in [pauseForRestart] uses this so a
    // very-early pause (before any progress callback) still gets a
    // plausible offset rather than reporting 0 / starting over.
    _reportingStartedMs = DateTime.now().millisecondsSinceEpoch;
    // Seed the pause snapshot with the chunk that the engine is about
    // to speak, so [pauseForRestart] can return a valid resume point
    // even if no progress callback has fired yet (e.g. user pauses
    // within ~50ms of starting). The snapshot is updated by every
    // subsequent [_onProgress] call.
    _lastFingerprintForPause = _activeFingerprint;
    _lastSpokenTextForPause = spokenText;
    _lastOffsetForPause = 0;
    // Reset the first-observation latch so the next progress callback
    // is treated as the first sample (no calibration update).
    _firstObservationSinceStart = true;
    if (resumeBaseline > 0) {
      // Resume call — the engine is now speaking a suffix of the
      // original chunk. The cubit pre-sets AudioState.position using
      // the *currently calibrated* msPerChar (see
      // SiteDetailCubit.resumeAudio), so the first progress callback
      // must use the same rate or the bar will jump. Reset the
      // observation anchor to the resume point so the first callback
      // enters the calibration loop directly instead of the
      // uncalibrated "first observation" branch.
      _lastObservedOffset = resumeBaseline;
      _lastObservationMs = DateTime.now().millisecondsSinceEpoch;
    } else {
      // Fresh play — seed the rate and observation anchors so the
      // first callback calibrates from the population estimate.
      _lastObservedOffset = 0;
      _lastObservationMs = 0;
      _msPerChar = 80; // 12.5 chars/sec seed until first callback refines it
    }
    // Capture the session token at registration time. The wrapper
    // closure gates the call on token equality — a stale progress
    // callback from a previous session is dropped before it can
    // overwrite the new bar's position. The fingerprint guard
    // (above) is the first line of defense; the token guard is
    // the second, in case the engine accidentally emits a callback
    // whose text still fingerprints-matches the new chunk.
    final myToken = _sessionToken;
    _activeOnPosition = (pos) {
      if (myToken != _sessionToken) return;
      onPosition(pos);
    };
  }

  /// Stop forwarding; safe to call multiple times or without a prior
  /// `startReportingPosition`. Drops the active handler so any in-flight
  /// native callbacks become no-ops.
  void stopReportingPosition() {
    _activeFingerprint = null;
    _activeSpokenText = null;
    _activeOnPosition = null;
    _activeResumeBaseline = 0;
    // We do NOT clear `_lastOffsetForPause` etc. here — the pause
    // snapshot needs to survive `stopReportingPosition` so that
    // `pauseForRestart` (called immediately after by the cubit) can
    // read a valid resume point. The snapshot is cleared by the
    // next `startReportingPosition` (which re-seeds it) or by a
    // successful `pauseForRestart` capture.
  }

  /// Re-install the progress reporter after an Android resume. The
  /// engine is now speaking a *suffix* of the original chunk (the text
  /// after the captured char offset), so the fingerprint and the
  /// baseline need to be swapped atomically. Without this, the next
  /// progress callback (whose `text` is the suffix) would mismatch the
  /// original fingerprint and the bar would freeze.
  ///
  /// [suffix] is the text the engine is currently speaking (i.e.
  /// `point.text.substring(point.charOffset)`). [baseline] is the
  /// char offset of the suffix's first character in the original chunk,
  /// used by [_offsetToDuration] to keep the visible position
  /// monotonic across the pause. [onPosition] and [budget] are the same
  /// values that would be passed to a fresh [startReportingPosition].
  void restartReportingWithSuffix({
    required String suffix,
    required int baseline,
    required ValueChanged<Duration> onPosition,
    required Duration budget,
  }) {
    startReportingPosition(
      suffix,
      onPosition: onPosition,
      budget: budget,
      resumeBaseline: baseline,
    );
  }

  /// Cheap fingerprint of the chunk — length + first/last 4 chars.
  /// Stale-callback dedup doesn't need cryptographic strength; it just
  /// needs to distinguish between two `speak()` calls in quick succession.
  String _fingerprint(String text) {
    final len = text.length;
    final head = text.length <= 4 ? text : text.substring(0, 4);
    final tail = text.length <= 4 ? '' : text.substring(text.length - 4);
    return '$len|$head|$tail';
  }

  /// Native callback — wired once in init. See `setProgressHandler`.
  /// Filters by fingerprint, then translates char-offset → Duration
  /// via self-calibration.
  void _onProgress(String text, int start, int end, String word) {
    final fp = _fingerprint(text);
    if (fp != _activeFingerprint) {
      return; // stale callback from a previous speak()
    }
    if (end <= 0) return;
    // Record the latest observed offset/text/fingerprint so a later
    // [pauseForRestart] (which may run AFTER [stopReportingPosition]
    // has cleared the live fields) can still recover the resume point.
    _lastOffsetForPause = end;
    _lastSpokenTextForPause = text;
    _lastFingerprintForPause = fp;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isFirst = _firstObservationSinceStart;
    final deltaOffset = end - _lastObservedOffset;
    final deltaMs = nowMs - _lastObservationMs;
    _firstObservationSinceStart = false;

    if (_lastObservedOffset == 0 || deltaOffset <= 0 || deltaMs <= 0) {
      // First valid observation since startReportingPosition — just
      // remember it and emit the seed position so the bar advances on
      // the very first callback.
      _lastObservedOffset = end;
      _lastObservationMs = nowMs;
      _activeOnPosition?.call(_offsetToDuration(end));
      return;
    }

    if (isFirst) {
      // First post-startReportingPosition sample. The Android engine
      // often fires a single huge `end` (the entire suffix on resume)
      // which would dramatically shift `_msPerChar` if we let it
      // through the 60/40 calibration mix. Just remember the sample
      // and emit the position — calibration picks up from the next
      // callback.
      _lastObservedOffset = end;
      _lastObservationMs = nowMs;
      _activeOnPosition?.call(_offsetToDuration(end));
      return;
    }

    // Rolling calibration: msPerChar = observed delta-ms / delta-offset.
    // Mix with the running estimate so a single noisy sample doesn't
    // swing the bar wildly.
    final observedMsPerChar = deltaMs / deltaOffset;
    _msPerChar = _msPerChar * 0.6 + observedMsPerChar * 0.4;
    _lastObservedOffset = end;
    _lastObservationMs = nowMs;
    _activeOnPosition?.call(_offsetToDuration(end));
  }

  /// Char-offset → Duration using the current self-calibrated rate.
  /// On Android resume the engine is speaking a suffix of the original
  /// chunk, so we add the resume baseline to the observed offset to
  /// produce a position that's monotonic across the pause.
  Duration _offsetToDuration(int charOffset) {
    if (charOffset <= 0) return Duration.zero;
    return Duration(
      milliseconds: ((charOffset + _activeResumeBaseline) * _msPerChar).round(),
    );
  }

  /// True until the first *post-startReportingPosition* progress
  /// callback has been observed. The first sample is always noisy —
  /// on Android resume especially, the engine can fire a single
  /// huge `end` (the entire suffix) immediately, which would
  /// dramatically shift `_msPerChar` if we let it through the
  /// 60/40 calibration mix. We use this flag to skip the calibration
  /// update on the first sample and emit the position only.
  bool _firstObservationSinceStart = true;

  /// Wall-clock timestamp at which the most recent
  /// `startReportingPosition` was called. Used by [pauseForRestart]'s
  /// wall-clock fallback when no progress callback has fired yet so
  /// the very-early pause case still produces a non-zero offset
  /// rather than restarting from the absolute beginning. Mirrors
  /// `_speakStartMs` but is independent of `_flutterTts.speak`
  /// having run — startReportingPosition is the contract point that
  /// the cubit actually waits for.
  int? _reportingStartedMs;

  /// Current self-calibrated ms/char rate. Exposed so the cubit can
  /// compute a baseline-adjusted position synchronously on Android
  /// resume (before the first progress callback fires). Falls back to
  /// the seed rate (80 ms/char ≈ 12.5 chars/sec) before any callback
  /// has been observed for the current speak().
  double get currentMsPerChar => _msPerChar;

  // --- Pause / resume (Android-safe) ----------------------------------

  /// Pause the engine in a way that survives across platforms. iOS uses
  /// the native `pause()` which keeps the engine's internal position;
  /// Android stops the utterance and snapshots the offset so the cubit
  /// can restart from the right place via [resumeFrom].
  ///
  /// Returns null on iOS (the engine keeps state) or when no chunk is
  /// currently being reported (nothing to resume from). Returns a
  /// [PausedResumePoint] on Android when we successfully captured a
  /// restart point.
  Future<PausedResumePoint?> pauseForRestart() async {
    // flutter_tts v4.x has no resume() method, so we use the same
    // stop-and-respeak approach on both iOS and Android. On iOS,
    // _flutterTts.pause() does call AVSpeechSynthesizer.pauseSpeaking(),
    // but there is no corresponding channel method to unpause, so the
    // engine would stay paused forever. Using stop() here on both
    // platforms is safe and ensures resumeFrom() can re-speak the
    // suffix correctly.
    //
    // We snapshot the active fields BEFORE clearing them. This call is
    // safe even if the caller already invoked `stopReportingPosition`
    // (which clears those fields to null) — we always read from the
    // snapshot, which is updated by [snapshotForPause] and persists
    // across `stopReportingPosition` / `invalidateSession` until the
    // next pause captures it.
    final captured = _lastOffsetForPause > 0 ? _lastOffsetForPause : _lastObservedOffset;
    final text = _lastSpokenTextForPause ?? _activeSpokenText;
    final fp = _lastFingerprintForPause ?? _activeFingerprint;
    // If the user paused before the engine reported a single progress
    // callback, the snapshot offset is 0 and we'd otherwise return
    // null (falling back to play-from-the-start in the cubit). The
    // engine IS speaking — synthesize an offset from wall-clock so a
    // very-early pause still resumes near the start instead of from
    // the absolute beginning.
    int offsetToReturn = captured;
    if (offsetToReturn <= 0 &&
        text != null &&
        fp != null &&
        _msPerChar > 0) {
      // Use whichever of the speak-start / reporter-start timestamps
      // is more recent so the wall-clock estimate reflects actual
      // elapsed playback time. The reporter-start stamp is set even
      // if `_flutterTts.speak` hasn't been called yet (the cubit
      // installs the reporter before speaking), giving us a usable
      // baseline in the very-early pause case.
      final startMs = _speakStartMs ?? _reportingStartedMs;
      if (startMs != null) {
        final elapsedMs = DateTime.now().millisecondsSinceEpoch - startMs;
        if (elapsedMs > 0) {
          final estimated = (elapsedMs / _msPerChar).round();
          offsetToReturn = estimated.clamp(1, text.length - 1);
        }
      }
    }
    // Clear _speakStartMs before stop() so the cancel handler doesn't
    // try to compute a duration from a now-stale start time.
    _speakStartMs = null;
    // Invalidate the session BEFORE the engine call so any late
    // completion callbacks from the cancelled utterance are dropped by
    // the token guard. The cubit will start a fresh session in
    // resumeAudio() by calling beginSession() via either startReporting
    // or a new speak().
    invalidateSession();
    await _flutterTts.stop();
    _state = TtsState.paused;
    // Clear the snapshot AFTER capturing so a subsequent pause on a
    // fresh play starts clean. We capture *before* invalidateSession()
    // wipes the regular fields, but the snapshot stays live through
    // the wipe so the capture is order-independent.
    _lastOffsetForPause = 0;
    _lastSpokenTextForPause = null;
    _lastFingerprintForPause = null;
    if (fp == null || text == null || offsetToReturn <= 0) return null;
    return PausedResumePoint(text: text, charOffset: offsetToReturn);
  }

  /// Snapshot of the most recent observed char offset, taken for use by
  /// [pauseForRestart]. We keep this in addition to the live
  /// [_lastObservedOffset] because [stopReportingPosition] (called by
  /// the cubit before pausing) clears the live fields to null — without
  /// the snapshot, the pause would always return null. Updated every
  /// time the engine reports progress. Reset on every successful
  /// [pauseForRestart] capture and on every new [startReportingPosition].
  int _lastOffsetForPause = 0;
  String? _lastSpokenTextForPause;
  String? _lastFingerprintForPause;

  /// Re-speak the suffix of [point.text] starting at [point.charOffset]
  /// and re-install the progress reporter with the matching baseline so
  /// the visible position picks up where the engine stopped, not at
  /// zero. No-op when the offset is already at end-of-text.
  ///
  /// Caller is expected to follow up with `startReportingPosition`
  /// (or `playAudio` re-emitting state) so the bar advances.
  Future<void> resumeFrom(PausedResumePoint point) async {
    if (point.charOffset >= point.text.length) return;
    final suffix = point.text.substring(point.charOffset);
    if (Platform.isAndroid) {
      // Defensive — make sure the previous utterance is fully released
      // before asking the engine for a new one.
      await _flutterTts.stop();
    }
    // Bug 6 fix: re-apply language before speaking. pauseForRestart()
    // calls _flutterTts.stop() on Android, which can silently release
    // the engine's voice handle. Without this, the resumed suffix plays
    // in silence — the same root cause as the stop→play voice loss.
    await _forceApplyLanguage(_currentLanguage);
    // Bug 7 fix: stamp the start time so the completion handler can
    // compute the real duration and fire _onCompletion. Without this,
    // _speakStartMs is null after a pause→resume cycle (because
    // pauseForRestart() triggers setCancelHandler which clears it).
    // As a result the loop never restarts for premium users after a
    // pause, and the bar keeps showing the estimate instead of the
    // real duration.
    _speakStartMs = DateTime.now().millisecondsSinceEpoch;
    await _flutterTts.speak(suffix);
    _state = TtsState.playing;
  }

  void dispose() {
    // Invalidate the session so any in-flight callback (e.g. a
    // completion from a torn-down parent) is dropped on the floor
    // before the engine is disposed.
    invalidateSession();
    _flutterTts.stop();
  }
}
