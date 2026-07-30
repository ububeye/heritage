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
  }) : _siteRepository = siteRepository ?? SiteRepository(),
       _ttsService = ttsService ?? TtsService(),
       _localizationCubit = localizationCubit,
       super(const SiteDetailState());
  final SiteRepository _siteRepository;
  final TtsService _ttsService;

  /// Optional handle to LocalizationCubit so we can surface TTS-voice
  /// fallbacks discovered during playback through the same SnackBar
  /// channel as UI-language changes. May be null in unit tests.
  final LocalizationCubit? _localizationCubit;

  /// Monotonic request counter for site loads. Bumped before every
  /// `loadSite` await so a slow first load doesn't overwrite the result
  /// of a faster second load. Without this, fast taps can paint site A
  /// into the detail screen for site B's id.
  int _loadSequenceId = 0;

  Future<void> loadSite(String siteId) async {
    final myId = ++_loadSequenceId;
    emit(state.copyWith(status: SiteDetailStatus.loading));

    try {
      final site = await _siteRepository.getSiteById(siteId);
      if (myId != _loadSequenceId || isClosed) return;
      if (site != null) {
        emit(state.copyWith(status: SiteDetailStatus.loaded, site: site));
      } else {
        emit(
          state.copyWith(
            status: SiteDetailStatus.error,
            errorMessage: 'Site not found',
          ),
        );
      }
    } catch (e) {
      if (myId != _loadSequenceId || isClosed) return;
      emit(
        state.copyWith(
          status: SiteDetailStatus.error,
          errorMessage: e.toString(),
        ),
      );
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

  /// Install (or reinstall) the TTS progress reporter. Used both on
  /// fresh play and after a pause/resume cycle so the closure shape
  /// lives in exactly one place.
  ///
  /// [baseline] is non-zero on Android resume — the engine is speaking
  /// a suffix of [spokenText], so every emitted Duration is offset by
  /// the chars that came before the resume point. The closure below
  /// still clamps against AudioState.duration, so the bar caps at
  /// the chunk's real total duration rather than the suffix's.
  void _reinstallProgressReporter({
    required String spokenText,
    required int baseline,
  }) {
    _ttsService.startReportingPosition(
      spokenText,
      budget: state.audioState.duration,
      resumeBaseline: baseline,
      onPosition: (pos) {
        if (isClosed) return;
        final current = state.audioState;
        if (!current.isPlaying) return;
        final clamped = pos > current.duration ? current.duration : pos;
        // Cheap guard against a freakishly large jump that would let
        // the bar shoot to the end on a single noisy callback.
        if ((clamped - current.position).inMilliseconds < 0) return;
        emit(state.copyWith(audioState: current.copyWith(position: clamped)));
        if (clamped >= current.duration) {
          _ttsService.stopReportingPosition();
          emit(
            state.copyWith(
              audioState: current.copyWith(
                position: current.duration,
                isPlaying: false,
              ),
            ),
          );
          if (current.wasTruncated && current.maxDurationSeconds != null) {
            _localizationCubit?.reportTtsPreviewEnded(
              maxSeconds: current.maxDurationSeconds!,
            );
          }
        }
      },
    );
  }

  Future<void> playAudio(String languageCode, {bool isPremium = false}) async {
    if (state.site == null) return;
    if (isClosed) return;

    _ttsService.stopReportingPosition();

    final text = state.site!.getDescription(languageCode);
    final maxSeconds = _ttsService.getMaxDuration();
    final estimatedDuration = _estimateDuration(text, maxSeconds);

    emit(
      state.copyWith(
        audioState: AudioState(
          isLoading: true,
          languageCode: languageCode,
          duration: estimatedDuration,
          maxDurationSeconds: maxSeconds,
        ),
      ),
    );
    if (isClosed) return;

    try {
      _ttsService.setPremium(isPremium);
      // Switch the TTS voice to the requested language *before* speak so
      // we can detect a missing voice and surface it via LocalizationCubit
      // (the same SnackBar listener that handles UI-language changes).
      // Only report a fallback when the engine actually ended up speaking
      // a different language — otherwise the SnackBar would say e.g.
      // "English voice not installed — playing in English".
      final outcome = await _ttsService.setLanguage(languageCode);
      if (isClosed) return;
      if (outcome == SetLanguageOutcome.voiceUnavailable) {
        final activeCode = _ttsService.currentLanguage.split('-').first;
        if (activeCode != languageCode) {
          _localizationCubit?.reportTtsFallback(
            requestedCode: languageCode,
            spokenCode: activeCode,
          );
        }
      }
      // Compute the chunk ourselves so we can hand the same string to
      // startReportingPosition — the engine's progress callback fires
      // with char offsets into the *spoken* text, so the chunk we
      // report against must equal the chunk the engine is saying.
      // Premium playback passes the full text straight through; the
      // chunk is identical for non-truncated cases.
      final chunk = _ttsService.previewChunkFor(text);
      final speakResult = await _ttsService.speak(
        text,
        languageCode: languageCode,
      );

      if (isClosed) return;
      emit(
        state.copyWith(
          audioState: state.audioState.copyWith(
            isLoading: false,
            isPlaying: true,
            position: Duration.zero,
            duration: estimatedDuration,
            // Stash the truncation flag on the audio state so screens can
            // render a "Preview" badge near the play button.
            wasTruncated: speakResult.wasTruncated,
            // Stash the chunk the engine will speak — the transcript
            // widget binds to this so it shows the spoken chunk, not the
            // full description in the UI language.
            spokenText: chunk.text,
            // A fresh play means any prior pausedResumePoint is stale.
            clearPausedResumePoint: true,
          ),
        ),
      );
      if (isClosed) return;

      // Forward real engine progress into AudioState.position. The TTS
      // service self-calibrates chars/sec from observed progress events;
      // we just emit clamped positions and detect end-of-chunk via the
      // existing duration gate (preview-ended SnackBar still fires here).
      _reinstallProgressReporter(baseline: 0, spokenText: chunk.text);
    } catch (e) {
      _ttsService.stopReportingPosition();
      if (isClosed) return;
      emit(
        state.copyWith(
          audioState: state.audioState.copyWith(
            isLoading: false,
            errorMessage: 'Failed to play audio',
          ),
        ),
      );
    }
  }

  Future<void> pauseAudio() async {
    _ttsService.stopReportingPosition();
    if (isClosed) return;
    // pauseForRestart is platform-aware: iOS uses native pause (engine
    // keeps its position internally), Android stops the engine and
    // returns a snapshot the cubit stashes on AudioState so resumeAudio
    // can re-speak the suffix from the right char offset.
    final resumePoint = await _ttsService.pauseForRestart();
    if (isClosed) return;
    emit(
      state.copyWith(
        audioState: state.audioState.copyWith(
          isPlaying: false,
          isPaused: true,
          pausedResumePoint: resumePoint,
        ),
      ),
    );
  }

  Future<void> resumeAudio() async {
    final point = state.audioState.pausedResumePoint;
    if (point == null) {
      // iOS path — the engine kept its own position. Native resume()
      // picks up exactly where it stopped, but its emitted char offsets
      // are into the original chunk (not from zero), so the bar would
      // jump backwards without a baseline. Derive the baseline from the
      // last-seen position using the currently calibrated chars/sec rate
      // — falls back to the seed rate (80 ms/char) before any callback
      // has been observed for the current speak().
      await _ttsService.resume();
      if (isClosed) return;
      final lastPosition = state.audioState.position;
      final resumeOffsetChars =
          (lastPosition.inMilliseconds / _ttsService.currentMsPerChar).round();
      emit(
        state.copyWith(
          audioState: state.audioState.copyWith(
            isPlaying: true,
            isPaused: false,
          ),
        ),
      );
      if (isClosed) return;
      _reinstallProgressReporter(
        baseline: resumeOffsetChars,
        spokenText: state.audioState.spokenText,
      );
      return;
    }

    // Android path — re-speak the suffix and shift the visible position
    // forward by the captured offset so the bar picks up where it left
    // off instead of snapping to zero.
    await _ttsService.resumeFrom(point);
    if (isClosed) return;
    final resumedAtMs =
        (point.charOffset * _ttsService.currentMsPerChar).round();
    emit(
      state.copyWith(
        audioState: state.audioState.copyWith(
          isPlaying: true,
          isPaused: false,
          position: Duration(milliseconds: resumedAtMs),
          // The resume point has been consumed.
          clearPausedResumePoint: true,
        ),
      ),
    );
    if (isClosed) return;
    // The engine is now speaking the suffix of the original chunk
    // (text from [point.charOffset] onwards). The progress callback
    // hands us the suffix's text, so the reporter's fingerprint must
    // match the suffix — otherwise the next callback mismatches and
    // the bar freezes. The baseline keeps [_offsetToDuration]
    // monotonic so the visible position doesn't snap back to zero.
    final suffix = point.text.substring(point.charOffset);
    _ttsService.restartReportingWithSuffix(
      suffix: suffix,
      baseline: point.charOffset,
      onPosition: (pos) {
        if (isClosed) return;
        final current = state.audioState;
        if (!current.isPlaying) return;
        final clamped = pos > current.duration ? current.duration : pos;
        if ((clamped - current.position).inMilliseconds < 0) return;
        emit(state.copyWith(audioState: current.copyWith(position: clamped)));
        if (clamped >= current.duration) {
          _ttsService.stopReportingPosition();
          emit(
            state.copyWith(
              audioState: current.copyWith(
                position: current.duration,
                isPlaying: false,
              ),
            ),
          );
          if (current.wasTruncated && current.maxDurationSeconds != null) {
            _localizationCubit?.reportTtsPreviewEnded(
              maxSeconds: current.maxDurationSeconds!,
            );
          }
        }
      },
      budget: state.audioState.duration,
    );
  }

  Future<void> stopAudio() async {
    _ttsService.stopReportingPosition();
    await _ttsService.stop();
    if (isClosed) return;
    emit(state.copyWith(audioState: const AudioState()));
  }

  @override
  Future<void> close() {
    _ttsService.stopReportingPosition();
    _ttsService.stop();
    return super.close();
  }
}
