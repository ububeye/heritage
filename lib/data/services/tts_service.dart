import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants/app_constants.dart';

enum TtsState { playing, stopped, paused, continued }

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

  Future<bool> setLanguage(String languageCode) async {
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
    if (ttsLanguage == null) return false;

    final availableLanguages = (await _flutterTts.getLanguages as List?)?.cast<String>() ?? [];
    if (!availableLanguages.contains(ttsLanguage)) {
      return false;
    }

    await _flutterTts.setLanguage(ttsLanguage);
    _currentLanguage = ttsLanguage;
    return true;
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

  Future<void> speak(String text, {String? languageCode}) async {
    if (text.isEmpty) return;

    if (languageCode != null) {
      await setLanguage(languageCode);
    }

    if (_isPremium) {
      await _flutterTts.speak(text);
      _state = TtsState.playing;
    } else {
      final limitedText = _truncateText(text, _maxDurationSeconds);
      await _flutterTts.speak(limitedText);
      _state = TtsState.playing;
    }
  }

  String _truncateText(String text, int maxSeconds) {
    final words = text.split(' ');
    const wordsPerSecond = 2.5;
    final maxWords = (maxSeconds * wordsPerSecond).round();

    if (words.length <= maxWords) return text;

    final truncated = words.take(maxWords).join(' ');
    return '$truncated...';
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
