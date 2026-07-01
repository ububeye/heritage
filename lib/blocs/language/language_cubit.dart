import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/shared_prefs_service.dart';

class LanguageCubit extends Cubit<LanguageState> {
  LanguageCubit() : super(const LanguageState());

  Future<void> loadLanguage() async {
    final prefs = SharedPrefsService.instance;
    final uiLanguage = prefs.uiLanguage;
    final audioLanguage = prefs.audioLanguage;

    emit(state.copyWith(
      uiLanguage: uiLanguage,
      audioLanguage: audioLanguage,
    ),);
  }

  Future<void> setUiLanguage(String languageCode) async {
    await SharedPrefsService.instance.setUiLanguage(languageCode);
    emit(state.copyWith(uiLanguage: languageCode));
  }

  Future<void> setAudioLanguage(String languageCode) async {
    await SharedPrefsService.instance.setAudioLanguage(languageCode);
    emit(state.copyWith(audioLanguage: languageCode));
  }
}

class LanguageState {

  const LanguageState({
    this.uiLanguage = 'en',
    this.audioLanguage = 'en',
  });
  final String uiLanguage;
  final String audioLanguage;

  LanguageState copyWith({
    String? uiLanguage,
    String? audioLanguage,
  }) {
    return LanguageState(
      uiLanguage: uiLanguage ?? this.uiLanguage,
      audioLanguage: audioLanguage ?? this.audioLanguage,
    );
  }
}