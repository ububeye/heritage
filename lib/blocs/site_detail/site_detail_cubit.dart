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

  /// Wall-clock ticker that advances `AudioState.position` while the
  /// engine is playing. The engine's `setProgressHandler` fires
  /// infrequently on Android (sometimes only at word boundaries), so
  /// the visible seconds-counter and progress bar would otherwise
  /// stall in long gaps between callbacks. The reporter's own
  /// callbacks can still override the ticker when they arrive (the
  /// existing `(clamped - current.position).inMilliseconds < 0` guard
  /// at line ~94 filters out backwards movement).
  Timer? _positionTicker;

  /// Single-shot latch for end-of-chunk handling. Both the reporter
  /// and the ticker independently detect end-of-chunk via
  /// `position >= duration`, and both fire the preview-ended
  /// SnackBar. Without coordination they can double-emit when the
  /// engine's last progress callback lands in the same microtask
  /// drain as a timer tick. Setting this flag on the first emit
  /// ensures the second emit is a no-op. Reset every time a new
  /// play or resume starts.
  bool _endOfChunkSignaled = false;

  Future<void> loadSite(String siteId) async {
    final myId = ++_loadSequenceId;

    // Immediately stop and invalidate any previous audio session so that
    // audio from site A never leaks or continues playing when moving to
    // site B. `invalidateSession` is the single source of truth here:
    // it bumps the engine's session token (so any in-flight progress /
    // completion / error callbacks for the previous utterance are
    // dropped on the floor), clears the active reporter, and detaches
    // the completion callback. The engine `stop()` call that follows
    // fires the cancel handler — by that point the token has already
    // been bumped, so the cancel handler cannot accidentally re-trigger
    // a replay.
    _ttsService.invalidateSession();
    _stopPositionTicker();
    await _ttsService.stop();
    ++_audioOpSeq;

    emit(
      state.copyWith(
        status: SiteDetailStatus.loading,
        audioState: const AudioState(),
      ),
    );

    try {
      final site = await _siteRepository.getSiteById(siteId);
      if (myId != _loadSequenceId || isClosed) return;
      if (site != null) {
        emit(
          state.copyWith(
            status: SiteDetailStatus.loaded,
            site: site,
            audioState: const AudioState(),
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: SiteDetailStatus.error,
            errorMessage: 'Site not found',
            audioState: const AudioState(),
          ),
        );
      }
    } catch (e) {
      if (myId != _loadSequenceId || isClosed) return;
      emit(
        state.copyWith(
          status: SiteDetailStatus.error,
          errorMessage: e.toString(),
          audioState: const AudioState(),
        ),
      );
    }
  }

  /// Compute a sensible bar-duration for [text]. Delegates to
  /// [TtsService.estimateDuration] which uses the same 2.5 words/sec
  /// constant as the sentence-boundary chunker — so the initial bar
  /// never shows a duration longer than the actual spoken chunk.
  ///
  /// For premium users the full text word-count is used; for free-tier
  /// users the result is capped at the current preview budget.
  Duration _estimateDuration(String text) {
    return _ttsService.estimateDuration(text);
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
    // Reset the end-of-chunk latch so this fresh play is allowed to
    // signal completion exactly once. The ticker is also starting
    // fresh — both will check this flag before emitting the
    // preview-ended SnackBar.
    _endOfChunkSignaled = false;
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
        if (clamped >= current.duration && !_endOfChunkSignaled) {
          _endOfChunkSignaled = true;
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

  /// Start the wall-clock position ticker. Called after the reporter is
  /// installed for a fresh play or a resume. The ticker advances
  /// `AudioState.position` by 100ms every 100ms while playing, so the
  /// seconds text and progress bar move smoothly even when the engine
  /// is between `setProgressHandler` callbacks. Real progress callbacks
  /// still override the ticker when they arrive (the reporter's
  /// emissions pass through the existing monotonicity guard).
  void _startPositionTicker() {
    _positionTicker?.cancel();
    _positionTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (isClosed) return;
      final current = state.audioState;
      if (!current.isPlaying) {
        _stopPositionTicker();
        return;
      }
      final next = current.position + const Duration(milliseconds: 100);
      if (next >= current.duration && !_endOfChunkSignaled) {
        // Hit end-of-chunk. Mirror the reporter's end-of-chunk branch
        // so the bar pins to the end and we surface the preview-ended
        // SnackBar exactly once. The shared latch prevents the
        // reporter and ticker from double-firing when the engine's
        // last progress callback lands in the same tick window.
        _endOfChunkSignaled = true;
        _ttsService.stopReportingPosition();
        _stopPositionTicker();
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
        return;
      }
      emit(state.copyWith(audioState: current.copyWith(position: next)));
    });
  }

  void _stopPositionTicker() {
    _positionTicker?.cancel();
    _positionTicker = null;
  }

  /// Monotonic generation counter for audio operations (play/pause/resume/stop).
  /// Bumped on every new audio operation so stale async completions from an
  /// earlier request cannot overwrite a newer state (e.g. rapid play->stop taps).
  int _audioOpSeq = 0;

  Future<void> playAudio(String languageCode, {bool isPremium = false}) async {
    if (state.site == null) return;
    if (isClosed) return;

    final activeSiteId = state.site!.id;
    final opId = ++_audioOpSeq;

    // Begin a fresh TTS session BEFORE doing any work. This bumps the
    // service's session token so any in-flight progress / completion /
    // error callbacks from the previous utterance (or from a previous
    // site) are dropped by the token guard wrapped around each
    // listener. The token is captured by the wrappers inside
    // startReportingPosition / setOnCompletion below — those wrappers
    // compare the captured token to the live token and bail when they
    // differ.
    _ttsService.beginSession();
    // Drop the previous reporter + completion callback eagerly. The
    // beginSession() bump already guards the wrapped closures, but
    // clearing the fields prevents the reporter from emitting one
    // last position update before the new session installs.
    _ttsService.stopReportingPosition();
    _ttsService.setOnCompletion(null);
    _ttsService.setPremium(isPremium);
    final text = state.site!.getDescription(languageCode);
    final estimatedDuration = _estimateDuration(text);

    emit(
      state.copyWith(
        audioState: AudioState(
          siteId: activeSiteId,
          isLoading: true,
          languageCode: languageCode,
          duration: estimatedDuration,
          maxDurationSeconds: _ttsService.getMaxDuration(),
        ),
      ),
    );
    if (isClosed || opId != _audioOpSeq) return;

    try {
      // Switch the TTS voice to the requested language *before* speak so
      // we can detect a missing voice and surface it via LocalizationCubit
      // (the same SnackBar listener that handles UI-language changes).
      // Only report a fallback when the engine actually ended up speaking
      // a different language — otherwise the SnackBar would say e.g.
      // "English voice not installed — playing in English".
      final outcome = await _ttsService.setLanguage(languageCode);
      if (isClosed || opId != _audioOpSeq) return;
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
      // Pass the precomputed chunk back into speak() so the engine
      // speaks exactly the same string we report against, even if a
      // premium flip races between the two calls.
      final chunk = _ttsService.previewChunkFor(text);
      final speakResult = await _ttsService.speak(
        text,
        languageCode: languageCode,
        precomputedChunk: chunk,
      );

      if (isClosed || opId != _audioOpSeq) return;
      emit(
        state.copyWith(
          audioState: state.audioState.copyWith(
            siteId: activeSiteId,
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
      if (isClosed || opId != _audioOpSeq) return;

      // Forward real engine progress into AudioState.position. The TTS
      // service self-calibrates chars/sec from observed progress events;
      // we just emit clamped positions and detect end-of-chunk via the
      // existing duration gate (preview-ended SnackBar still fires here).
      _reinstallProgressReporter(baseline: 0, spokenText: chunk.text);
      _startPositionTicker();

      // Fix 2: Infinite auto-replay for premium users.
      //
      // Register a completion callback on TtsService. When the engine
      // reaches the natural end of the utterance it fires this closure
      // with the *real* measured duration so the bar shows accurate
      // MM:SS on every subsequent loop. Premium users get an automatic
      // replay; free-tier users get the existing preview-ended SnackBar
      // (which is already fired by the progress reporter / ticker above).
      //
      // The closure is wrapped by setOnCompletion() with a session
      // token check — if a previous session's completion handler races
      // through here (e.g. site A → site B before A's completion fired),
      // the wrapper drops it on the floor.
      _ttsService.setOnCompletion((realDuration) {
        if (isClosed || opId != _audioOpSeq) return;
        final current = state.audioState;
        if (isPremium) {
          // Update the stored duration with the real measured value so
          // the bar is accurate from the very next loop start.
          final accurate = state.audioState.copyWith(
            siteId: activeSiteId,
            duration: realDuration,
            position: Duration.zero,
            isPlaying: false,
          );
          emit(state.copyWith(audioState: accurate));
          // Re-invoke playAudio to loop. The completion callback will be
          // re-registered inside the recursive playAudio call, so
          // infinite replay continues until the user taps Stop/Pause.
          playAudio(languageCode, isPremium: isPremium);
        } else {
          // Free-tier: update duration with real value but do not replay.
          // (The preview-ended SnackBar is already fired by the reporter.)
          emit(
            state.copyWith(
              audioState: current.copyWith(
                siteId: activeSiteId,
                duration: realDuration,
                position: realDuration,
                isPlaying: false,
              ),
            ),
          );
        }
      });
    } catch (e) {
      if (isClosed || opId != _audioOpSeq) return;
      _ttsService.invalidateSession();
      _stopPositionTicker();
      emit(
        state.copyWith(
          audioState: state.audioState.copyWith(
            siteId: activeSiteId,
            isLoading: false,
            isPlaying: false,
            errorMessage: 'Failed to play audio',
          ),
        ),
      );
    }
  }

  Future<void> pauseAudio() async {
    final opId = ++_audioOpSeq;
    final activeSiteId = state.site?.id;
    if (isClosed) return;
    // pauseForRestart() stops the engine and snapshots the current
    // char offset on both iOS and Android. flutter_tts v4.x has no
    // resume() method, so both platforms use the stop-and-respeak
    // approach: the engine is stopped here and re-started from the
    // captured offset in resumeAudio() via resumeFrom().
    //
    // pauseForRestart() bumps the session token internally. The
    // resumeAudio() path will begin a fresh session before installing
    // its reporter — the token gate prevents the PRE-pause completion
    // callback (if it races past our await) from firing into the new
    // session.
    //
    // We run pauseForRestart BEFORE tearing down the reporter. The
    // earlier ordering (stopReporter → pauseForRestart) cleared the
    // active fields to null before the snapshot could be captured,
    // which made every pause return null and caused every resume to
    // fall back to playAudio — i.e. the customer-visible
    // "starts from beginning" bug. pauseForRestart now reads from a
    // dedicated snapshot that survives stopReportingPosition, but we
    // also reorder for belt-and-braces.
    final resumePoint = await _ttsService.pauseForRestart();
    if (isClosed || opId != _audioOpSeq) return;
    _ttsService.stopReportingPosition();
    _stopPositionTicker();
    emit(
      state.copyWith(
        audioState: state.audioState.copyWith(
          siteId: activeSiteId,
          isPlaying: false,
          isPaused: true,
          pausedResumePoint: resumePoint,
        ),
      ),
    );
  }

  Future<void> resumeAudio() async {
    final audio = state.audioState;
    final point = audio.pausedResumePoint;
    final currentSite = state.site;

    // If there is no active site, or no captured resume point, or if the audio state
    // was captured for a different site, fall back deterministically to playAudio() from
    // the start of the current site's description.
    if (currentSite == null ||
        point == null ||
        (audio.siteId != null && audio.siteId != currentSite.id)) {
      final langCode = audio.languageCode;
      final isPremium = audio.maxDurationSeconds == null;
      await playAudio(langCode, isPremium: isPremium);
      return;
    }

    final activeSiteId = currentSite.id;
    final opId = ++_audioOpSeq;
    final suffix = point.text.substring(point.charOffset);
    final langCode = audio.languageCode;
    final isPremium = audio.maxDurationSeconds == null;

    // Begin a fresh TTS session so the new reporter and completion
    // callback capture the post-pause token. pauseForRestart() bumped
    // the token at pause time; the beginSession() here produces a new
    // value that the wrapped closures will compare against. A
    // late-arriving completion from the pre-pause session is dropped
    // by the wrapper's token mismatch.
    _ttsService.beginSession();

    // Reset the end-of-chunk latch so the resume is allowed to signal completion once.
    _endOfChunkSignaled = false;

    // 1. Install progress reporter with the suffix fingerprint and baseline
    // BEFORE starting speech so early callbacks from the engine are not dropped.
    _ttsService.restartReportingWithSuffix(
      suffix: suffix,
      baseline: point.charOffset,
      onPosition: (pos) {
        if (isClosed || opId != _audioOpSeq) return;
        final current = state.audioState;
        if (!current.isPlaying) return;
        final clamped = pos > current.duration ? current.duration : pos;
        if ((clamped - current.position).inMilliseconds < 0) return;
        emit(state.copyWith(audioState: current.copyWith(position: clamped)));
        if (clamped >= current.duration && !_endOfChunkSignaled) {
          _endOfChunkSignaled = true;
          _ttsService.stopReportingPosition();
          _stopPositionTicker();
          emit(
            state.copyWith(
              audioState: current.copyWith(
                siteId: activeSiteId,
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
      budget: audio.duration,
    );

    // 2. Re-register completion callback for resumed audio so infinite replay / completion cleanly works.
    _ttsService.setOnCompletion((realDuration) {
      if (isClosed || opId != _audioOpSeq) return;
      final current = state.audioState;
      if (isPremium) {
        final accurate = state.audioState.copyWith(
          siteId: activeSiteId,
          duration: realDuration,
          position: Duration.zero,
          isPlaying: false,
        );
        emit(state.copyWith(audioState: accurate));
        playAudio(langCode, isPremium: isPremium);
      } else {
        emit(
          state.copyWith(
            audioState: current.copyWith(
              siteId: activeSiteId,
              duration: realDuration,
              position: realDuration,
              isPlaying: false,
            ),
          ),
        );
      }
    });

    final resumedAtMs =
        (point.charOffset * _ttsService.currentMsPerChar).round();
    emit(
      state.copyWith(
        audioState: audio.copyWith(
          siteId: activeSiteId,
          isPlaying: true,
          isPaused: false,
          position: Duration(milliseconds: resumedAtMs),
          clearPausedResumePoint: true,
        ),
      ),
    );

    _startPositionTicker();

    // 3. Re-speak suffix via TTS engine
    await _ttsService.resumeFrom(point);
    if (isClosed || opId != _audioOpSeq) return;
  }

  /// Forward a new speech-rate multiplier to the TTS engine immediately.
  /// Called by the Settings playback-speed tile after saving to SharedPrefs
  /// so the current session hears the change without restarting the app.
  Future<void> applyPlaybackSpeed(double speed) async {
    await _ttsService.applyPlaybackSpeed(speed);
  }

  Future<void> stopAudio() async {
    final opId = ++_audioOpSeq;
    _ttsService.stopReportingPosition();
    _stopPositionTicker();
    _endOfChunkSignaled = false;
    // Invalidate the session BEFORE the engine stop so any in-flight
    // completion callback for the previous utterance is dropped by the
    // token guard. The cancel handler then fires on the engine stop,
    // but by that point _onCompletion is already null and the token
    // has already been bumped — there's no path for a replay to fire.
    _ttsService.invalidateSession();
    await _ttsService.stop();
    if (isClosed || opId != _audioOpSeq) return;
    emit(state.copyWith(audioState: const AudioState()));
  }

  @override
  Future<void> close() {
    ++_audioOpSeq;
    _ttsService.invalidateSession();
    _stopPositionTicker();
    _ttsService.stop();
    return super.close();
  }
}
