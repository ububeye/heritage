import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_constants.dart';
import '../../data/services/shared_prefs_service.dart';
import '../../data/services/tts_service.dart';

class LocalizationCubit extends Cubit<LocalizationState> {
  LocalizationCubit({required TtsService ttsService})
    : _ttsService = ttsService,
      super(const LocalizationState()) {
    // Forward native TTS engine errors into the same SnackBar channel as
    // voice-fallback and preview-ended. Without this, a "no network" or
    // missing-voice failure shows as a silent dead bar.
    _ttsService.setOnError((message) {
      reportTtsEngineError(message);
    });
  }

  final TtsService _ttsService;

  /// Monotonic request counter for language loads. Bumped before every
  /// `_loadJsonFile` and `setLanguage` await. After the await resolves we
  /// compare against `_loadSeq`; a stale value means a newer request has
  /// started and the result must be discarded. Without this, rapid
  /// EN→SW→EN taps can leave `translations` from SW but
  /// `currentLanguage='en'`.
  int _loadSeq = 0;

  /// Validate a language code against the supported UI languages. Unknown
  /// codes (e.g. a stale SharedPreferences value or a future RTL locale
  /// without a translation file) fall back to English and surface a
  /// SnackBar via [invalidLanguageNotice] so the user understands why
  /// their pick didn't stick.
  String _validateUiLanguage(String code) {
    if (AppConstants.uiLanguages.contains(code)) return code;
    return 'en';
  }

  /// True when the requester asked for an unsupported code. The root
  /// listener picks this up and shows a one-shot SnackBar.
  String? _invalidLanguageNotice;

  /// Returns (and clears) any pending "unsupported language" notice.
  /// Called by the root listener in [app.dart] via BlocListener.
  String? consumeInvalidLanguageNotice() {
    final n = _invalidLanguageNotice;
    _invalidLanguageNotice = null;
    return n;
  }

  Future<void> loadTranslations() async {
    final prefs = SharedPrefsService.instance;
    final rawCode = prefs.uiLanguage;
    final languageCode = _validateUiLanguage(rawCode);
    if (languageCode != rawCode) {
      await SharedPrefsService.instance.setUiLanguage(languageCode);
    }

    final token = ++_loadSeq;
    emit(state.copyWith(status: LocalizationStatus.loading));

    try {
      final translations = await _loadJsonFile(languageCode);
      if (token != _loadSeq) return; // raced with a newer request
      // Sync the TTS voice to the persisted UI language on startup so a
      // user who set Swahili last session hears Swahili when they hit play,
      // not whatever voice the engine booted with. We only surface a
      // fallback signal when the requested voice is unavailable AND the
      // engine's active voice is genuinely different from what the user
      // asked for — otherwise the SnackBar would say e.g. "English voice
      // not installed — playing in English", which is useless.
      final outcome = await _ttsService.setLanguage(languageCode);
      if (token != _loadSeq) return; // raced with a newer request
      final activeCode = _ttsService.currentLanguage.split('-').first;
      final isGenuineFallback =
          outcome == SetLanguageOutcome.voiceUnavailable &&
          activeCode != languageCode;
      emit(
        state.copyWith(
          status: LocalizationStatus.loaded,
          currentLanguage: languageCode,
          translations: translations,
          ttsFallback: isGenuineFallback ? activeCode : null,
          ttsFallbackRequested: isGenuineFallback ? languageCode : null,
        ),
      );
    } catch (e) {
      if (token != _loadSeq) return;
      emit(state.copyWith(status: LocalizationStatus.error));
    }
  }

  Future<void> setLanguage(String languageCode) async {
    final resolved = _validateUiLanguage(languageCode);
    if (resolved != languageCode) {
      _invalidLanguageNotice = languageCode;
    }
    final token = ++_loadSeq;
    await SharedPrefsService.instance.setUiLanguage(resolved);

    try {
      final translations = await _loadJsonFile(resolved);
      if (token != _loadSeq) return;
      // Mirror the UI language onto the TTS engine. Only emit a fallback
      // signal when the engine ended up speaking something different from
      // what the user asked for; otherwise the SnackBar is misleading.
      final outcome = await _ttsService.setLanguage(resolved);
      if (token != _loadSeq) return;
      final activeCode = _ttsService.currentLanguage.split('-').first;
      final isGenuineFallback =
          outcome == SetLanguageOutcome.voiceUnavailable &&
          activeCode != resolved;
      emit(
        state.copyWith(
          currentLanguage: resolved,
          translations: translations,
          ttsFallback: isGenuineFallback ? activeCode : null,
          ttsFallbackRequested: isGenuineFallback ? resolved : null,
        ),
      );
    } catch (e) {
      if (token != _loadSeq) return;
      // Fallback to English
      final translations = await _loadJsonFile('en');
      if (token != _loadSeq) return;
      final outcome = await _ttsService.setLanguage('en');
      if (token != _loadSeq) return;
      final activeCode = _ttsService.currentLanguage.split('-').first;
      final isGenuineFallback =
          outcome == SetLanguageOutcome.voiceUnavailable && activeCode != 'en';
      emit(
        state.copyWith(
          currentLanguage: 'en',
          translations: translations,
          ttsFallback: isGenuineFallback ? activeCode : null,
          ttsFallbackRequested: isGenuineFallback ? 'en' : null,
        ),
      );
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
    emit(
      state.copyWith(
        ttsFallback: spokenCode,
        ttsFallbackRequested: requestedCode,
      ),
    );
  }

  /// Surface the fact that a free-tier playback hit the per-session
  /// time cap and stopped at a sentence boundary. The root listener
  /// shows a SnackBar prompting the user to upgrade. [maxSeconds] is
  /// the cap value so the SnackBar can render e.g. "30-second preview
  /// ended — upgrade to keep listening."
  void reportTtsPreviewEnded({required int maxSeconds}) {
    emit(state.copyWith(ttsPreviewEndedAt: maxSeconds));
  }

  /// Reset the preview-ended signal after the UI has shown the SnackBar
  /// so the same state doesn't re-trigger on rebuild.
  void clearTtsPreviewEnded() {
    if (state.ttsPreviewEndedAt != null) {
      emit(state.copyWith(clearTtsPreviewEnded: true));
    }
  }

  /// Surface a native-TTS engine error (network failure, plugin
  /// exception, missing voice). The root listener shows a SnackBar and
  /// then calls [clearTtsEngineError] so rebuilds don't re-trigger.
  void reportTtsEngineError(String message) {
    emit(state.copyWith(ttsEngineError: message));
  }

  /// Reset the engine-error signal after the SnackBar has fired.
  void clearTtsEngineError() {
    if (state.ttsEngineError != null) {
      emit(state.copyWith(clearTtsEngineError: true));
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
    this.ttsEngineError,
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

  /// Set to the native-engine error message when the TTS plugin reports
  /// a failure (network down, missing voice, plugin exception). Cleared
  /// by the listener after the SnackBar has fired so rebuilds don't
  /// re-trigger.
  final String? ttsEngineError;

  LocalizationState copyWith({
    LocalizationStatus? status,
    String? currentLanguage,
    Map<String, String>? translations,
    String? ttsFallback,
    String? ttsFallbackRequested,
    int? ttsPreviewEndedAt,
    String? ttsEngineError,
    bool clearTtsFallback = false,
    bool clearTtsPreviewEnded = false,
    bool clearTtsEngineError = false,
  }) {
    return LocalizationState(
      status: status ?? this.status,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      translations: translations ?? this.translations,
      ttsFallback: clearTtsFallback ? null : (ttsFallback ?? this.ttsFallback),
      ttsFallbackRequested:
          clearTtsFallback
              ? null
              : (ttsFallbackRequested ?? this.ttsFallbackRequested),
      ttsPreviewEndedAt:
          clearTtsPreviewEnded
              ? null
              : (ttsPreviewEndedAt ?? this.ttsPreviewEndedAt),
      ttsEngineError:
          clearTtsEngineError ? null : (ttsEngineError ?? this.ttsEngineError),
    );
  }
}

enum LocalizationStatus { initial, loading, loaded, error }

// Helper function to get translated string
extension LocalizationExtension on Map<String, String> {
  String tr(String key) => this[key] ?? key;
}
