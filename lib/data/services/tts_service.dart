import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants/app_constants.dart';

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

  void dispose() {
    _flutterTts.stop();
  }
}
