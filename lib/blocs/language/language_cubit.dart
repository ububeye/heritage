import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/shared_prefs_service.dart';

class LanguageCubit extends Cubit<LanguageState> {
  LanguageCubit() : super(const LanguageState());

  Future<void> loadLanguage() async {
    final prefs = SharedPrefsService.instance;
    final audioLanguage = prefs.audioLanguage;

    emit(state.copyWith(audioLanguage: audioLanguage));
  }

  Future<void> setAudioLanguage(String languageCode) async {
    await SharedPrefsService.instance.setAudioLanguage(languageCode);
    emit(state.copyWith(audioLanguage: languageCode));
  }
}

class LanguageState {
  const LanguageState({this.audioLanguage = 'en'});
  final String audioLanguage;

  LanguageState copyWith({String? audioLanguage}) {
    return LanguageState(audioLanguage: audioLanguage ?? this.audioLanguage);
  }
}
