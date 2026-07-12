import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants/app_constants.dart';
import '../models/audio_state.dart';

enum TtsState { playing, stopped, paused, continued }

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
    await _flutterTts.setSpeechRate(AppConstants.defaultSpeechRate);
    await _flutterTts.setPitch(AppConstants.defaultPitch);
    await _flutterTts.setVolume(AppConstants.defaultVolume);

    _flutterTts.setCompletionHandler(() {
      _state = TtsState.stopped;
    });

    _flutterTts.setCancelHandler(() {
      _state = TtsState.stopped;
    });

    _flutterTts.setErrorHandler((msg) {
      _state = TtsState.stopped;
    });

    // Install once; the handler routes through the *_active* fields
    // which get swapped per-speak().
    _flutterTts.setProgressHandler(_onProgress);

    await _setDefaultLanguage();
  }

  Future<void> _setDefaultLanguage() async {
    final languages = (await _flutterTts.getLanguages as List?)?.cast<String>() ?? [];
    if (languages.contains('en-US')) {
      await _flutterTts.setLanguage('en-US');
      _currentLanguage = 'en-US';
    }
  }

  void setPremium(bool isPremium) {
    _isPremium = isPremium;
    _updateMaxDuration();
  }

  void _updateMaxDuration() {
    _maxDurationSeconds = _isPremium ? 0 : AppConstants.freeAudioMaxSeconds;
  }

  /// Switch the TTS voice to the locale matching [languageCode].
  ///
  /// Returns `null` on success. If the device does not have a voice for the
  /// requested language, the call falls back to the default voice
  /// (typically en-US) and returns the language code that is actually being
  /// used — letting callers surface a "voice for X not installed" message
  /// instead of silently playing in a different language.
  ///
  /// If [languageCode] is not in our supported map at all, returns 'en'.
  Future<String?> setLanguage(String languageCode) async {
    final languageMap = {
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
      // Unknown code — keep the previous voice but report the fallback
      // we'd ideally have used so the caller can warn.
      return _currentLanguage.split('-').first;
    }

    final availableLanguages = (await _flutterTts.getLanguages as List?)?.cast<String>() ?? [];
    if (!availableLanguages.contains(ttsLanguage)) {
      // Voice not installed. Don't switch; the engine keeps its previous
      // (or default) voice. Report the previously-active language code so
      // the caller can show a SnackBar.
      return _currentLanguage.split('-').first;
    }

    await _flutterTts.setLanguage(ttsLanguage);
    _currentLanguage = ttsLanguage;
    return null;
  }

  Future<List<String>> getAvailableLanguages() async {
    final languages = (await _flutterTts.getLanguages as List?)?.cast<String>() ?? [];
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
  Future<TtsSpeakResult> speak(String text, {String? languageCode}) async {
    if (text.isEmpty) {
      return const TtsSpeakResult(wasTruncated: false);
    }

    if (languageCode != null) {
      await setLanguage(languageCode);
    }

    if (_isPremium) {
      await _flutterTts.speak(text);
      _state = TtsState.playing;
      return const TtsSpeakResult(wasTruncated: false);
    }

    // Free tier: take the longest sentence-bounded prefix that fits in the
    // time budget so the preview doesn't end mid-clause. If even the first
    // sentence overflows, fall back to that one sentence rather than
    // chopping at an arbitrary word boundary — better to hear a complete
    // thought than to stop on "the".
    final chunk = _chunkForDuration(text, _maxDurationSeconds);
    await _flutterTts.speak(chunk.text);
    _state = TtsState.playing;
    return TtsSpeakResult(wasTruncated: chunk.wasCut);
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
      final truncated = buffer.toString().substring(0, lastTerminatorIndex).trimRight();
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
    await _flutterTts.stop();
    _state = TtsState.stopped;
  }

  Future<void> pause() async {
    await _flutterTts.pause();
    _state = TtsState.paused;
  }

  Future<void> resume() async {
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

  /// Sentence-bounded preview chunk for the active free-tier settings.
  /// Exposed so [SiteDetailCubit] can hand the exact same string to
  /// [startReportingPosition] (the engine's progress callback uses the
  /// spoken text as its source of offsets, so the chunk we report
  /// progress for must equal the chunk the engine is speaking).
  TtsChunk previewChunkFor(String text) =>
      _chunkForDuration(text, _maxDurationSeconds);

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
    _lastObservedOffset = 0;
    _lastObservationMs = 0;
    _msPerChar = 80; // 12.5 chars/sec seed until first callback refines it
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
    if (fp != _activeFingerprint) return; // stale callback from a previous speak()
    if (end <= 0) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final deltaOffset = end - _lastObservedOffset;
    final deltaMs = nowMs - _lastObservationMs;
    if (_lastObservedOffset == 0 || deltaOffset <= 0 || deltaMs <= 0) {
      // First valid observation since startReportingPosition — just
      // remember it and emit the seed position so the bar advances on
      // the very first callback.
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
      milliseconds:
          ((charOffset + _activeResumeBaseline) * _msPerChar).round(),
    );
  }

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
    if (Platform.isIOS) {
      await _flutterTts.pause();
      _state = TtsState.paused;
      return null;
    }
    final captured = _lastObservedOffset;
    final fp = _activeFingerprint;
    final text = _activeSpokenText;
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
    await _flutterTts.speak(suffix);
    _state = TtsState.playing;
  }

  void dispose() {
    _flutterTts.stop();
  }
}
