import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/shared_prefs_service.dart';
import '../../data/services/tts_service.dart';

class LanguageCubit extends Cubit<LanguageState> {
  LanguageCubit({TtsService? ttsService})
    : _ttsService = ttsService,
      super(const LanguageState());

  /// Optional TTS engine — when injected, an audio-language change
  /// drives the engine's voice immediately so a premium customer
  /// picking French in Settings hears French on the very next
  /// playAudio, not "on the next session restart" (which is what
  /// happened before: only the SharedPrefs were updated, the engine
  /// kept its previous voice until the first speak() ran the
  /// candidate resolver again).
  ///
  /// Optional for tests — `LanguageCubit()` constructs without a
  /// TTS service, so unit tests don't need to mock flutter_tts.
  final TtsService? _ttsService;

  Future<void> loadLanguage() async {
    final prefs = SharedPrefsService.instance;
    final audioLanguage = prefs.audioLanguage;

    emit(state.copyWith(audioLanguage: audioLanguage));
  }

  Future<void> setAudioLanguage(String languageCode) async {
    await SharedPrefsService.instance.setAudioLanguage(languageCode);
    emit(state.copyWith(audioLanguage: languageCode));
    // Drive the engine immediately so a Settings change doesn't
    // require a playAudio to take effect. We swallow engine errors
    // silently — the engine's own error handler surfaces them via
    // the SnackBar channel; this cubit only cares about the
    // persisted preference. Use `unawaited` so we don't block the
    // caller's rebuild path waiting for the engine.
    final tts = _ttsService;
    if (tts != null) {
      // Fire-and-forget; the engine resolves the language via the
      // candidate walker so a device without the exact requested
      // locale falls back to the closest installed variant. We do
      // not re-emit the cubit's audioLanguage based on the result —
      // the SharedPreferences value is the source of truth, the
      // engine's voice is a derived display property.
      tts.setLanguage(languageCode);
    }
  }
}

class LanguageState {
  const LanguageState({this.audioLanguage = 'en'});
  final String audioLanguage;

  LanguageState copyWith({String? audioLanguage}) {
    return LanguageState(audioLanguage: audioLanguage ?? this.audioLanguage);
  }
}
