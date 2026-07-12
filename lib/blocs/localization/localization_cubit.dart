import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/shared_prefs_service.dart';
import '../../data/services/tts_service.dart';

class LocalizationCubit extends Cubit<LocalizationState> {
  LocalizationCubit({required TtsService ttsService})
      : _ttsService = ttsService,
        super(const LocalizationState());

  final TtsService _ttsService;

  Future<void> loadTranslations() async {
    final prefs = SharedPrefsService.instance;
    final languageCode = prefs.uiLanguage;

    emit(state.copyWith(status: LocalizationStatus.loading));

    try {
      final translations = await _loadJsonFile(languageCode);
      // Sync the TTS voice to the persisted UI language on startup so a
      // user who set Swahili last session hears Swahili when they hit play,
      // not whatever voice the engine booted with.
      final ttsFallback = await _ttsService.setLanguage(languageCode);
      emit(state.copyWith(
        status: LocalizationStatus.loaded,
        currentLanguage: languageCode,
        translations: translations,
        ttsFallback: ttsFallback,
        ttsFallbackRequested: ttsFallback == null ? null : languageCode,
      ),);
    } catch (e) {
      emit(state.copyWith(status: LocalizationStatus.error));
    }
  }

  Future<void> setLanguage(String languageCode) async {
    await SharedPrefsService.instance.setUiLanguage(languageCode);

    try {
      final translations = await _loadJsonFile(languageCode);
      // Mirror the UI language onto the TTS engine. If the device doesn't
      // have a matching voice, ttsFallback carries the language code that
      // is actually being spoken — UI listens for that and shows a SnackBar.
      final ttsFallback = await _ttsService.setLanguage(languageCode);
      emit(state.copyWith(
        currentLanguage: languageCode,
        translations: translations,
        ttsFallback: ttsFallback,
        ttsFallbackRequested: ttsFallback == null ? null : languageCode,
      ),);
    } catch (e) {
      // Fallback to English
      final translations = await _loadJsonFile('en');
      final ttsFallback = await _ttsService.setLanguage('en');
      emit(state.copyWith(
        currentLanguage: 'en',
        translations: translations,
        ttsFallback: ttsFallback,
        ttsFallbackRequested: ttsFallback == null ? null : 'en',
      ),);
    }
  }

  /// Surface a TTS-voice fallback that came from outside this cubit
  /// (currently: SiteDetailCubit.playAudio, where the audio-language pick
  /// differs from the UI language). [requestedCode] is what the user picked,
  /// [spokenCode] is what the engine will actually use.
  void reportTtsFallback({
    required String requestedCode,
    required String spokenCode,
  }) {
    if (requestedCode == spokenCode) return;
    emit(state.copyWith(
      ttsFallback: spokenCode,
      ttsFallbackRequested: requestedCode,
    ),);
  }

  /// Surface the fact that a free-tier playback hit the per-session
  /// time cap and stopped at a sentence boundary. The root listener
  /// shows a SnackBar prompting the user to upgrade. [maxSeconds] is
  /// the cap value so the SnackBar can render e.g. "30-second preview
  /// ended — upgrade to keep listening."
  void reportTtsPreviewEnded({required int maxSeconds}) {
    emit(state.copyWith(ttsPreviewEndedAt: maxSeconds),);
  }

  /// Reset the preview-ended signal after the UI has shown the SnackBar
  /// so the same state doesn't re-trigger on rebuild.
  void clearTtsPreviewEnded() {
    if (state.ttsPreviewEndedAt != null) {
      emit(state.copyWith(clearTtsPreviewEnded: true),);
    }
  }

  /// Manually clear the ttsFallback signal after the UI has shown the
  /// SnackBar so the same state isn't redisplayed on rebuild.
  void clearTtsFallback() {
    if (state.ttsFallback != null) {
      emit(state.copyWith(clearTtsFallback: true));
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
    this.ttsFallback,
    this.ttsFallbackRequested,
    this.ttsPreviewEndedAt,
  });
  final LocalizationStatus status;
  final String currentLanguage;
  final Map<String, String> translations;

  /// Non-null when the user requested one UI language but the TTS engine
  /// could not switch to a matching voice and is using a different one.
  /// Holds the language code actually being spoken (e.g. 'en') so the UI
  /// can render a localized "voice not installed" message.
  final String? ttsFallback;

  /// The language code the user actually requested when the fallback fired.
  /// For UI-language changes this matches [currentLanguage]; for audio-
  /// language changes (via SiteDetailCubit) it can differ — the listener
  /// uses it to render the SnackBar's "X voice not installed" prefix.
  final String? ttsFallbackRequested;

  /// Set to the free-tier cap (in seconds) when SiteDetailCubit reports
  /// that a preview just ended at a sentence boundary. Non-null is the
  /// signal; the value lets the listener render the right duration in
  /// the SnackBar ("30-second preview ended…").
  final int? ttsPreviewEndedAt;

  LocalizationState copyWith({
    LocalizationStatus? status,
    String? currentLanguage,
    Map<String, String>? translations,
    String? ttsFallback,
    String? ttsFallbackRequested,
    int? ttsPreviewEndedAt,
    bool clearTtsFallback = false,
    bool clearTtsPreviewEnded = false,
  }) {
    return LocalizationState(
      status: status ?? this.status,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      translations: translations ?? this.translations,
      ttsFallback: clearTtsFallback ? null : (ttsFallback ?? this.ttsFallback),
      ttsFallbackRequested: clearTtsFallback
          ? null
          : (ttsFallbackRequested ?? this.ttsFallbackRequested),
      ttsPreviewEndedAt: clearTtsPreviewEnded
          ? null
          : (ttsPreviewEndedAt ?? this.ttsPreviewEndedAt),
    );
  }
}

enum LocalizationStatus { initial, loading, loaded, error }

// Helper function to get translated string
extension LocalizationExtension on Map<String, String> {
  String tr(String key) => this[key] ?? key;
}
