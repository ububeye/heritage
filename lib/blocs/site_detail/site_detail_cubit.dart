import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/audio_state.dart';
import '../../data/repositories/site_repository.dart';
import '../../data/services/tts_service.dart';
import 'site_detail_state.dart';

class SiteDetailCubit extends Cubit<SiteDetailState> {
  final SiteRepository _siteRepository;
  final TtsService _ttsService;

  SiteDetailCubit({
    SiteRepository? siteRepository,
    TtsService? ttsService,
  })  : _siteRepository = siteRepository ?? SiteRepository(),
        _ttsService = ttsService ?? TtsService(),
        super(const SiteDetailState());

  Future<void> loadSite(String siteId) async {
    emit(state.copyWith(status: SiteDetailStatus.loading));

    try {
      final site = await _siteRepository.getSiteById(siteId);
      if (site != null) {
        emit(state.copyWith(
          status: SiteDetailStatus.loaded,
          site: site,
        ));
      } else {
        emit(state.copyWith(
          status: SiteDetailStatus.error,
          errorMessage: 'Site not found',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: SiteDetailStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> playAudio(String languageCode, {bool isPremium = false}) async {
    if (state.site == null) return;

    emit(state.copyWith(
      audioState: state.audioState.copyWith(
        isLoading: true,
        languageCode: languageCode,
      ),
    ));

    try {
      _ttsService.setPremium(isPremium);
      final text = state.site!.getDescription(languageCode);

      await _ttsService.speak(text, languageCode: languageCode);

      emit(state.copyWith(
        audioState: state.audioState.copyWith(
          isLoading: false,
          isPlaying: true,
        ),
      ));
    } catch (e) {
      emit(state.copyWith(
        audioState: state.audioState.copyWith(
          isLoading: false,
          errorMessage: 'Failed to play audio',
        ),
      ));
    }
  }

  Future<void> pauseAudio() async {
    await _ttsService.pause();
    emit(state.copyWith(
      audioState: state.audioState.copyWith(
        isPlaying: false,
        isPaused: true,
      ),
    ));
  }

  Future<void> resumeAudio() async {
    await _ttsService.resume();
    emit(state.copyWith(
      audioState: state.audioState.copyWith(
        isPlaying: true,
        isPaused: false,
      ),
    ));
  }

  Future<void> stopAudio() async {
    await _ttsService.stop();
    emit(state.copyWith(
      audioState: const AudioState(),
    ));
  }

  @override
  Future<void> close() {
    _ttsService.stop();
    return super.close();
  }
}