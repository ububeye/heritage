import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/audio_state.dart';
import '../../data/repositories/site_repository.dart';
import '../../data/services/tts_service.dart';
import '../localization/localization_cubit.dart';
import 'site_detail_state.dart';

class SiteDetailCubit extends Cubit<SiteDetailState> {

  SiteDetailCubit({
    SiteRepository? siteRepository,
    TtsService? ttsService,
    LocalizationCubit? localizationCubit,
  })  : _siteRepository = siteRepository ?? SiteRepository(),
        _ttsService = ttsService ?? TtsService(),
        _localizationCubit = localizationCubit,
        super(const SiteDetailState());
  final SiteRepository _siteRepository;
  final TtsService _ttsService;

  /// Optional handle to LocalizationCubit so we can surface TTS-voice
  /// fallbacks discovered during playback through the same SnackBar
  /// channel as UI-language changes. May be null in unit tests.
  final LocalizationCubit? _localizationCubit;

  /// Periodic timer used to advance the visible audio progress bar. The
  /// `flutter_tts` plugin does not report playback position, so we drive the
  /// bar from a local timer instead. See [AudioState.progress].
  Timer? _progressTimer;

  /// How often the progress bar advances. 250 ms gives smooth movement
  /// without burning CPU.
  static const Duration _progressTick = Duration(milliseconds: 250);

  Future<void> loadSite(String siteId) async {
    emit(state.copyWith(status: SiteDetailStatus.loading));

    try {
      final site = await _siteRepository.getSiteById(siteId);
      if (site != null) {
        emit(state.copyWith(
          status: SiteDetailStatus.loaded,
          site: site,
        ),);
      } else {
        emit(state.copyWith(
          status: SiteDetailStatus.error,
          errorMessage: 'Site not found',
        ),);
      }
    } catch (e) {
      emit(state.copyWith(
        status: SiteDetailStatus.error,
        errorMessage: e.toString(),
      ),);
    }
  }

  /// Compute a sensible bar-duration for [text]. We can't know the real TTS
  /// duration without running it, so we fall back to a 15 chars/sec estimate
  /// when the service doesn't expose a max length (premium, unlimited).
  Duration _estimateDuration(String text, int? maxSeconds) {
    if (maxSeconds != null && maxSeconds > 0) {
      return Duration(seconds: maxSeconds);
    }
    final seconds = (text.length / 15).ceil().clamp(5, 600);
    return Duration(seconds: seconds);
  }

  void _startProgressTimer(Duration total) {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(_progressTick, (_) {
      final current = state.audioState;
      if (!current.isPlaying || current.duration == Duration.zero) return;
      final next = current.position + _progressTick;
      if (next >= current.duration) {
        // Reached the end — snap to duration and stop the timer. The TTS
        // completion handler will fire on its own; this is purely visual.
        _progressTimer?.cancel();
        _progressTimer = null;
        emit(state.copyWith(
          audioState: current.copyWith(
            position: current.duration,
            isPlaying: false,
          ),
        ),);
        return;
      }
      emit(state.copyWith(
        audioState: current.copyWith(position: next),
      ),);
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<void> playAudio(String languageCode, {bool isPremium = false}) async {
    if (state.site == null) return;

    _stopProgressTimer();

    final text = state.site!.getDescription(languageCode);
    final maxSeconds = _ttsService.getMaxDuration();
    final estimatedDuration = _estimateDuration(text, maxSeconds);

    emit(state.copyWith(
      audioState: AudioState(
        isLoading: true,
        languageCode: languageCode,
        duration: estimatedDuration,
      ),
    ),);

    try {
      _ttsService.setPremium(isPremium);
      // Switch the TTS voice to the requested language *before* speak so
      // we can detect a missing voice and surface it via LocalizationCubit
      // (the same SnackBar listener that handles UI-language changes).
      final fallback = await _ttsService.setLanguage(languageCode);
      if (fallback != null) {
        _localizationCubit?.reportTtsFallback(
          requestedCode: languageCode,
          spokenCode: fallback,
        );
      }
      await _ttsService.speak(text, languageCode: languageCode);

      emit(state.copyWith(
        audioState: state.audioState.copyWith(
          isLoading: false,
          isPlaying: true,
          position: Duration.zero,
          duration: estimatedDuration,
        ),
      ),);

      // Start ticking. If the user already paused/resumed before this
      // point, the timer won't run because isPlaying would be false.
      _startProgressTimer(estimatedDuration);
    } catch (e) {
      _stopProgressTimer();
      emit(state.copyWith(
        audioState: state.audioState.copyWith(
          isLoading: false,
          errorMessage: 'Failed to play audio',
        ),
      ),);
    }
  }

  Future<void> pauseAudio() async {
    _stopProgressTimer();
    await _ttsService.pause();
    emit(state.copyWith(
      audioState: state.audioState.copyWith(
        isPlaying: false,
        isPaused: true,
      ),
    ),);
  }

  Future<void> resumeAudio() async {
    await _ttsService.resume();
    emit(state.copyWith(
      audioState: state.audioState.copyWith(
        isPlaying: true,
        isPaused: false,
      ),
    ),);
    _startProgressTimer(state.audioState.duration);
  }

  Future<void> stopAudio() async {
    _stopProgressTimer();
    await _ttsService.stop();
    emit(state.copyWith(
      audioState: const AudioState(),
    ),);
  }

  @override
  Future<void> close() {
    _stopProgressTimer();
    _ttsService.stop();
    return super.close();
  }
}
