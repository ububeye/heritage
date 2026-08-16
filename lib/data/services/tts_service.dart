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
  void setOnError(ValueChanged<String>? onError) {
    _onError = onError;
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
  void setOnCompletion(ValueChanged<Duration>? onCompletion) {
    _onCompletion = onCompletion;
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
      // safely trigger replay without a double-fire race.
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
      // by a user-initiated stop.
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
  /// the longest concatenation of whole sentences whose estimated speech
  /// time fits in [maxSeconds].
  TtsChunk _chunkForDuration(String text, int maxSeconds) {
    const wordsPerSecond = 2.5;
    final maxWords = (maxSeconds * wordsPerSecond).round();

    if (text.trim().split(RegExp(r'\s+')).length <= maxWords) {
      return TtsChunk(text: text, wasCut: false);
    }

    // Walk character-by-character, tracking word count and the index of
    // the last sentence terminator. We never slice mid-word — the chunk
    // is either the full text, a prefix ending at the last terminator
    // within the budget, or (as a safety net) the first sentence even
    // if it overflows the budget.
    int words = 0;
    int? lastTerminatorIndex;
    final buffer = StringBuffer();
    final chars = text.split('');
    bool inWord = false;

    for (int i = 0; i < chars.length; i++) {
      final c = chars[i];
      buffer.write(c);

      final isWhitespace = RegExp(r'\s').hasMatch(c);
      if (!isWhitespace && !inWord) {
        inWord = true;
        words++;
        if (words > maxWords) break;
      } else if (isWhitespace && inWord) {
        inWord = false;
      }

      // Sentence terminator — capture this position so we can return up
      // to and including it once we exceed the budget on the next word.
      if (c == '.' || c == '!' || c == '?' || c == '؟' || c == '،') {
        lastTerminatorIndex = buffer.length;
      }
    }

    if (words <= maxWords) {
      // We never hit the budget; the whole text fits.
      return TtsChunk(text: buffer.toString(), wasCut: false);
    }

    if (lastTerminatorIndex != null && lastTerminatorIndex > 0) {
      // Truncate at the last sentence boundary within the budget.
      final truncated =
          buffer.toString().substring(0, lastTerminatorIndex).trimRight();
      return TtsChunk(text: truncated, wasCut: true);
    }

    // No terminator found at all — fall back to the first word we hit
    // when we exceeded the budget, then append a brief cue so the user
    // hears *something* coherent and a hint to upgrade.
    final fallback = buffer.toString().trimRight();
    return TtsChunk(
      text: '$fallback. Upgrade to hear the full tour.',
      wasCut: true,
    );
  }

  Future<void> stop() async {
    // Clear the start-time stamp before stop() so the cancel handler
    // (which flutter_tts fires on stop()) does not accidentally compute
    // a bogus duration and trigger replay.
    _speakStartMs = null;
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
    _activeOnPosition = onPosition;
    _activeResumeBaseline = resumeBaseline;
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
  }

  /// Stop forwarding; safe to call multiple times or without a prior
  /// `startReportingPosition`. Drops the active handler so any in-flight
  /// native callbacks become no-ops.
  void stopReportingPosition() {
    _activeFingerprint = null;
    _activeSpokenText = null;
    _activeOnPosition = null;
    _activeResumeBaseline = 0;
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
    final captured = _lastObservedOffset;
    final fp = _activeFingerprint;
    final text = _activeSpokenText;
    // Clear _speakStartMs before stop() so the cancel handler doesn't
    // try to compute a duration from a now-stale start time.
    _speakStartMs = null;
    await _flutterTts.stop();
    _state = TtsState.paused;
    if (fp == null || text == null || captured <= 0) return null;
    return PausedResumePoint(text: text, charOffset: captured);
  }

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
    _flutterTts.stop();
  }
}
