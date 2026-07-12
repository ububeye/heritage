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

  Future<void> playAudio(String languageCode, {bool isPremium = false}) async {
    if (state.site == null) return;

    _ttsService.stopReportingPosition();

    final text = state.site!.getDescription(languageCode);
    final maxSeconds = _ttsService.getMaxDuration();
    final estimatedDuration = _estimateDuration(text, maxSeconds);

    emit(state.copyWith(
      audioState: AudioState(
        isLoading: true,
        languageCode: languageCode,
        duration: estimatedDuration,
        maxDurationSeconds: maxSeconds,
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
      // Compute the chunk ourselves so we can hand the same string to
      // startReportingPosition — the engine's progress callback fires
      // with char offsets into the *spoken* text, so the chunk we
      // report against must equal the chunk the engine is saying.
      // Premium playback passes the full text straight through; the
      // chunk is identical for non-truncated cases.
      final chunk = _ttsService.previewChunkFor(text);
      final speakResult =
          await _ttsService.speak(text, languageCode: languageCode);

      if (isClosed) return;
      emit(state.copyWith(
        audioState: state.audioState.copyWith(
          isLoading: false,
          isPlaying: true,
          position: Duration.zero,
          duration: estimatedDuration,
          // Stash the truncation flag on the audio state so screens can
          // render a "Preview" badge near the play button.
          wasTruncated: speakResult.wasTruncated,
        ),
      ),);

      // Forward real engine progress into AudioState.position. The TTS
      // service self-calibrates chars/sec from observed progress events;
      // we just emit clamped positions and detect end-of-chunk via the
      // existing duration gate (preview-ended SnackBar still fires here).
      final budget = state.audioState.duration;
      _ttsService.startReportingPosition(
        chunk.text,
        budget: budget,
        onPosition: (pos) {
          if (isClosed) return;
          final current = state.audioState;
          if (!current.isPlaying) return;
          final clamped =
              pos > current.duration ? current.duration : pos;
          // Cheap guard against a freakishly large jump that would let
          // the bar shoot to the end on a single noisy callback.
          if ((clamped - current.position).inMilliseconds < 0) return;
          emit(state.copyWith(
            audioState: current.copyWith(position: clamped),
          ),);
          if (clamped >= current.duration) {
            _ttsService.stopReportingPosition();
            emit(state.copyWith(
              audioState: current.copyWith(
                position: current.duration,
                isPlaying: false,
              ),
            ),);
            if (current.wasTruncated && current.maxDurationSeconds != null) {
              _localizationCubit?.reportTtsPreviewEnded(
                maxSeconds: current.maxDurationSeconds!,
              );
            }
          }
        },
      );
    } catch (e) {
      _ttsService.stopReportingPosition();
      emit(state.copyWith(
        audioState: state.audioState.copyWith(
          isLoading: false,
          errorMessage: 'Failed to play audio',
        ),
      ),);
    }
  }

  Future<void> pauseAudio() async {
    _ttsService.stopReportingPosition();
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
    // Re-install the reporter — stopReportingPosition was called in
    // pauseAudio, so we need a fresh calibration. We pass the same
    // chunked text the engine is speaking so char offsets line up.
    // The Android-pause-is-a-no-op bug is out of scope here; if it
    // bites, the bar will drift until the next stop/play cycle.
    if (state.site != null) {
      final audioLang = state.audioState.languageCode;
      final spoken = _ttsService.previewChunkFor(
        state.site!.getDescription(audioLang),
      );
      _ttsService.startReportingPosition(
        spoken.text,
        budget: state.audioState.duration,
        onPosition: (pos) {
          if (isClosed) return;
          final current = state.audioState;
          if (!current.isPlaying) return;
          final clamped =
              pos > current.duration ? current.duration : pos;
          if ((clamped - current.position).inMilliseconds < 0) return;
          emit(state.copyWith(
            audioState: current.copyWith(position: clamped),
          ),);
        },
      );
    }
  }

  Future<void> stopAudio() async {
    _ttsService.stopReportingPosition();
    await _ttsService.stop();
    emit(state.copyWith(
      audioState: const AudioState(),
    ),);
  }

  @override
  Future<void> close() {
    _ttsService.stopReportingPosition();
    _ttsService.stop();
    return super.close();
  }
}
