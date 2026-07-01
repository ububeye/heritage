import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/shared_prefs_service.dart';

class LocalizationCubit extends Cubit<LocalizationState> {
  LocalizationCubit() : super(const LocalizationState());

  Future<void> loadTranslations() async {
    final prefs = SharedPrefsService.instance;
    final languageCode = prefs.uiLanguage;

    emit(state.copyWith(status: LocalizationStatus.loading));

    try {
      final translations = await _loadJsonFile(languageCode);
      emit(state.copyWith(
        status: LocalizationStatus.loaded,
        currentLanguage: languageCode,
        translations: translations,
      ),);
    } catch (e) {
      emit(state.copyWith(status: LocalizationStatus.error));
    }
  }

  Future<void> setLanguage(String languageCode) async {
    await SharedPrefsService.instance.setUiLanguage(languageCode);

    try {
      final translations = await _loadJsonFile(languageCode);
      emit(state.copyWith(
        currentLanguage: languageCode,
        translations: translations,
      ),);
    } catch (e) {
      // Fallback to English
      final translations = await _loadJsonFile('en');
      emit(state.copyWith(
        currentLanguage: 'en',
        translations: translations,
      ),);
    }
  }

  Future<Map<String, String>> _loadJsonFile(String languageCode) async {
    final String jsonString = await rootBundle.loadString(
      'assets/localization/$languageCode.json',
    );
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    return jsonMap.map((key, value) => MapEntry(key, value.toString()));
  }

  String translate(String key) {
    return state.translations[key] ?? key;
  }

  String get currentLanguage => state.currentLanguage;
}

class LocalizationState {

  const LocalizationState({
    this.status = LocalizationStatus.initial,
    this.currentLanguage = 'en',
    this.translations = const {},
  });
  final LocalizationStatus status;
  final String currentLanguage;
  final Map<String, String> translations;

  LocalizationState copyWith({
    LocalizationStatus? status,
    String? currentLanguage,
    Map<String, String>? translations,
  }) {
    return LocalizationState(
      status: status ?? this.status,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      translations: translations ?? this.translations,
    );
  }
}

enum LocalizationStatus { initial, loading, loaded, error }

// Helper function to get translated string
extension LocalizationExtension on Map<String, String> {
  String tr(String key) => this[key] ?? key;
}
