// Tests for Fix 2 (startReportingPosition resumeBaseline branching) and
// Fix 3 (the wall-clock position ticker in SiteDetailCubit).
//
// We use handwritten fakes (consistent with the existing test suite)
// rather than mocktail, since the project doesn't depend on a mocking
// library. Time is controlled via `package:fake_async` so we can drive
// the cubit's Timer.periodic forward without waiting in real time.
//
// What Fix 3 adds:
//   - Timer? _positionTicker (100ms periodic) advances AudioState.position
//     while playing.
//   - End-of-chunk: when next >= duration, the ticker emits
//     position = duration, isPlaying = false, calls
//     ttsService.stopReportingPosition(), and if wasTruncated and
//     maxDurationSeconds != null, surfaces the preview-ended SnackBar
//     via LocalizationCubit.reportTtsPreviewEnded.
//   - Wired into playAudio, resumeAudio (both iOS and Android paths),
//     pauseAudio, stopAudio, the playAudio catch block, and close().

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stone_town_heritage_vt_guide/blocs/site_detail/site_detail_cubit.dart';
import 'package:stone_town_heritage_vt_guide/blocs/site_detail/site_detail_state.dart';
import 'package:stone_town_heritage_vt_guide/blocs/localization/localization_cubit.dart';
import 'package:stone_town_heritage_vt_guide/data/models/audio_state.dart';
import 'package:stone_town_heritage_vt_guide/data/models/site_model.dart';
import 'package:stone_town_heritage_vt_guide/data/repositories/site_repository.dart';
import 'package:stone_town_heritage_vt_guide/data/services/shared_prefs_service.dart';
import 'package:stone_town_heritage_vt_guide/data/services/tts_service.dart';

/// Site repository fake that returns a pre-built site.
class _FakeSiteRepository implements SiteRepository {
  _FakeSiteRepository(this._site);
  final SiteModel? _site;

  @override
  Future<SiteModel?> getSiteById(String id) async => _site;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_FakeSiteRepository.${invocation.memberName} not stubbed',
    );
  }
}

/// TTS service fake tailored for the audio-state-machine tests.
///
/// Captures every interaction the cubit performs (setPremium, setLanguage,
/// speak, startReportingPosition, stopReportingPosition, pauseForRestart,
/// resume, resumeFrom, restartReportingWithSuffix, stop). Lets the caller
/// tune the speak result and the duration override.
class _FakeTtsService implements TtsService {
  _FakeTtsService({
    TtsSpeakResult? speakResult,
  }) : speakResult = speakResult ??
            const TtsSpeakResult(
              wasTruncated: false,
            );

  TtsSpeakResult speakResult;

  /// When non-null, getMaxDuration returns this value instead of 30. The
  /// cubit uses getMaxDuration to derive AudioState.duration via
  /// _estimateDuration, so we can use this to drive the end-of-chunk
  /// tests with a short 1-second duration.
  int? maxDurationOverride;

  /// When non-null, pauseForRestart returns this instead of null.
  PausedResumePoint? pauseResumePoint;

  // Counters for assertions.
  int setPremiumCalls = 0;
  int setLanguageCalls = 0;
  int speakCalls = 0;
  int startReportingPositionCalls = 0;
  int stopReportingPositionCalls = 0;
  int pauseForRestartCalls = 0;
  int resumeCalls = 0;
  int resumeFromCalls = 0;
  int restartReportingWithSuffixCalls = 0;
  int stopCalls = 0;

  // Arguments captured for the most recent reporter install.
  String? lastReporterSpokenText;
  int lastReporterBaseline = -1;

  @override
  void setOnError(ValueChanged<String>? onError) {}

  @override
  void setPremium(bool isPremium) {
    setPremiumCalls++;
  }

  @override
  Future<SetLanguageOutcome> setLanguage(String languageCode) async {
    setLanguageCalls++;
    return SetLanguageOutcome.ok;
  }

  @override
  Future<TtsSpeakResult> speak(
    String text, {
    String? languageCode,
    TtsChunk? precomputedChunk,
  }) async {
    speakCalls++;
    return speakResult;
  }

  @override
  Future<List<String>> getAvailableLanguages() async => const ['en'];

  @override
  int? getMaxDuration() => maxDurationOverride ?? 30;

  @override
  TtsChunk previewChunkFor(String text) =>
      TtsChunk(text: text, wasCut: false);

  @override
  void startReportingPosition(
    String spokenText, {
    required ValueChanged<Duration> onPosition,
    required Duration budget,
    int resumeBaseline = 0,
  }) {
    startReportingPositionCalls++;
    lastReporterSpokenText = spokenText;
    lastReporterBaseline = resumeBaseline;
  }

  @override
  void stopReportingPosition() {
    stopReportingPositionCalls++;
  }

  @override
  void restartReportingWithSuffix({
    required String suffix,
    required int baseline,
    required ValueChanged<Duration> onPosition,
    required Duration budget,
  }) {
    restartReportingWithSuffixCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {
    resumeCalls++;
  }

  @override
  Future<void> resumeFrom(PausedResumePoint point) async {
    resumeFromCalls++;
  }

  @override
  Future<PausedResumePoint?> pauseForRestart() async {
    pauseForRestartCalls++;
    return pauseResumePoint;
  }

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  Future<void> setVolume(double volume) async {}

  @override
  TtsState get state => TtsState.stopped;

  @override
  bool get isPlaying => false;

  @override
  bool get isPremium => false;

  @override
  String get currentLanguage => 'en-US';

  @override
  double get currentMsPerChar => 80.0;

  @override
  void setFreeAudioMaxSeconds(int seconds) {}

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_FakeTtsService.${invocation.memberName} not stubbed',
    );
  }
}

/// Localization cubit fake that records `reportTtsPreviewEnded` calls so
/// we can assert the end-of-chunk SnackBar fires when wasTruncated.
class _FakeLocalizationCubit extends LocalizationCubit {
  _FakeLocalizationCubit() : super(ttsService: _NoopTtsService());

  final List<int> previewEndedCalls = <int>[];

  @override
  void reportTtsPreviewEnded({required int maxSeconds}) {
    previewEndedCalls.add(maxSeconds);
  }
}

/// Minimal TTS service stub that LocalizationCubit's constructor needs.
class _NoopTtsService implements TtsService {
  @override
  void setOnError(ValueChanged<String>? onError) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_NoopTtsService.${invocation.memberName} not stubbed',
    );
  }
}

/// Build a minimal site with a description long enough that the
/// cubit's _estimateDuration fallback doesn't clamp to 5s.
SiteModel _makeSite({
  String description =
      'Stone Town is a living museum of Swahili coastal trade, '
          'carved doors, coral rag walls, and centuries of Omani, '
          'Persian, Indian, and European influence converging on the '
          'western shore of Zanzibar island. Wander the narrow lanes '
          'and every doorway tells a story of merchants and sultans.',
}) {
  return SiteModel(
    id: 'site-1',
    nameEn: 'Stone Town',
    nameSw: 'Mji Mkongwe',
    descriptionEn: description,
    descriptionSw: description,
    descriptionFr: description,
    descriptionDe: description,
    descriptionAr: description,
    descriptionIt: description,
    descriptionEs: description,
    cloudinaryImageUrl: '',
    latitude: -6.1629,
    longitude: 39.1939,
  );
}

Future<void> _seedPrefs() async {
  SharedPreferences.setMockInitialValues({});
  await SharedPrefsService.getInstance();
}

void main() {
  setUpAll(_seedPrefs);

  group('Fix 3 — wall-clock position ticker', () {
    test('playAudio starts a 100ms ticker that advances position', () {
      fakeAsync((async) {
        final site = _makeSite();
        final tts = _FakeTtsService();
        final repo = _FakeSiteRepository(site);
        final loc = _FakeLocalizationCubit();
        final cubit = SiteDetailCubit(
          siteRepository: repo,
          ttsService: tts,
          localizationCubit: loc,
        );
        cubit.emit(
          SiteDetailState(status: SiteDetailStatus.loaded, site: site),
        );

        final playFuture = cubit.playAudio('en');
        // Drain the microtask queue so speak() completes and the
        // ticker starts.
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 500));

        expect(cubit.state.audioState.isPlaying, isTrue);
        expect(
          cubit.state.audioState.position,
          const Duration(milliseconds: 500),
          reason: 'five 100ms ticks should advance position by 500ms',
        );
        expect(tts.startReportingPositionCalls, 1);

        playFuture.then((_) => cubit.close());
      });
    });

    test('Timer is cancelled on pauseAudio — position stops advancing', () {
      fakeAsync((async) {
        final site = _makeSite();
        final tts = _FakeTtsService();
        final repo = _FakeSiteRepository(site);
        final loc = _FakeLocalizationCubit();
        final cubit = SiteDetailCubit(
          siteRepository: repo,
          ttsService: tts,
          localizationCubit: loc,
        );
        cubit.emit(
          SiteDetailState(status: SiteDetailStatus.loaded, site: site),
        );

        final playFuture = cubit.playAudio('en');
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 300));
        final positionAfterPlay = cubit.state.audioState.position;
        expect(positionAfterPlay, const Duration(milliseconds: 300));

        final pauseFuture = cubit.pauseAudio();
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 500));

        expect(cubit.state.audioState.isPlaying, isFalse);
        expect(cubit.state.audioState.isPaused, isTrue);
        // Position should not have advanced during the 500ms after pause.
        expect(
          cubit.state.audioState.position,
          positionAfterPlay,
          reason: 'ticker should be cancelled after pauseAudio',
        );

        playFuture.then((_) => pauseFuture.then((_) => cubit.close()));
      });
    });

    test('Timer is cancelled on stopAudio — state resets to default', () {
      fakeAsync((async) {
        final site = _makeSite();
        final tts = _FakeTtsService();
        final repo = _FakeSiteRepository(site);
        final loc = _FakeLocalizationCubit();
        final cubit = SiteDetailCubit(
          siteRepository: repo,
          ttsService: tts,
          localizationCubit: loc,
        );
        cubit.emit(
          SiteDetailState(status: SiteDetailStatus.loaded, site: site),
        );

        final playFuture = cubit.playAudio('en');
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 300));
        expect(cubit.state.audioState.isPlaying, isTrue);

        final stopFuture = cubit.stopAudio();
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 500));

        expect(cubit.state.audioState, const AudioState());
        expect(cubit.state.audioState.isPlaying, isFalse);
        expect(cubit.state.audioState.isPaused, isFalse);
        expect(cubit.state.audioState.position, Duration.zero);

        playFuture.then((_) => stopFuture.then((_) => cubit.close()));
      });
    });

    test(
      'end-of-chunk: ticker pins position to duration and stops playback',
      () {
        // Drive the duration to 1s via the maxDuration override so the
        // ticker can hit end-of-chunk within a single fake-second.
        fakeAsync((async) {
          final site = _makeSite();
          final tts = _FakeTtsService()..maxDurationOverride = 1;
          final repo = _FakeSiteRepository(site);
          final loc = _FakeLocalizationCubit();
          final cubit = SiteDetailCubit(
            siteRepository: repo,
            ttsService: tts,
            localizationCubit: loc,
          );
          cubit.emit(
            SiteDetailState(status: SiteDetailStatus.loaded, site: site),
          );

          final playFuture = cubit.playAudio('en');
          async.flushMicrotasks();

          expect(
            cubit.state.audioState.duration,
            const Duration(seconds: 1),
            reason: 'getMaxDuration override should yield a 1s duration',
          );

          // 1.1s of fake time → ~11 ticks → end-of-chunk branch fires.
          async.elapse(const Duration(milliseconds: 1100));

          expect(cubit.state.audioState.isPlaying, isFalse);
          expect(
            cubit.state.audioState.position,
            cubit.state.audioState.duration,
            reason: 'ticker should pin position to duration on end-of-chunk',
          );
          expect(
            tts.stopReportingPositionCalls >= 1,
            isTrue,
            reason:
                'end-of-chunk should call stopReportingPosition at least once',
          );

          playFuture.then((_) => cubit.close());
        });
      },
    );

    test(
      'end-of-chunk: reportTtsPreviewEnded fires when wasTruncated',
      () {
        fakeAsync((async) {
          final site = _makeSite();
          final tts = _FakeTtsService(
            speakResult: const TtsSpeakResult(
              wasTruncated: true,
            ),
          )..maxDurationOverride = 1;
          final repo = _FakeSiteRepository(site);
          final loc = _FakeLocalizationCubit();
          final cubit = SiteDetailCubit(
            siteRepository: repo,
            ttsService: tts,
            localizationCubit: loc,
          );
          cubit.emit(
            SiteDetailState(status: SiteDetailStatus.loaded, site: site),
          );

          final playFuture = cubit.playAudio('en');
          async.flushMicrotasks();
          async.elapse(const Duration(milliseconds: 1100));

          expect(cubit.state.audioState.wasTruncated, isTrue);
          expect(
            loc.previewEndedCalls,
            isNotEmpty,
            reason:
                'preview-ended SnackBar should fire when wasTruncated + '
                'end-of-chunk',
          );
          expect(loc.previewEndedCalls.first, 1);

          playFuture.then((_) => cubit.close());
        });
      },
    );

    test('close() cancels the ticker', () {
      fakeAsync((async) {
        final site = _makeSite();
        final tts = _FakeTtsService();
        final repo = _FakeSiteRepository(site);
        final loc = _FakeLocalizationCubit();
        final cubit = SiteDetailCubit(
          siteRepository: repo,
          ttsService: tts,
          localizationCubit: loc,
        );
        cubit.emit(
          SiteDetailState(status: SiteDetailStatus.loaded, site: site),
        );

        final playFuture = cubit.playAudio('en');
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 300));
        expect(cubit.state.audioState.isPlaying, isTrue);

        playFuture.then((_) async {
          await cubit.close();
          // Advance time well past what the ticker would have ticked —
          // closing must cancel it. No state changes should occur, and
          // no exception should be thrown by the now-cancelled timer.
          async.elapse(const Duration(seconds: 5));
        });
      });
    });
  });

  group('Fix 2 — startReportingPosition resumeBaseline branching', () {
    test(
      'playAudio installs reporter with baseline=0 (fresh-play seed)',
      () {
        fakeAsync((async) {
          final site = _makeSite();
          final tts = _FakeTtsService();
          final repo = _FakeSiteRepository(site);
          final loc = _FakeLocalizationCubit();
          final cubit = SiteDetailCubit(
            siteRepository: repo,
            ttsService: tts,
            localizationCubit: loc,
          );
          cubit.emit(
            SiteDetailState(status: SiteDetailStatus.loaded, site: site),
          );

          final playFuture = cubit.playAudio('en');
          async.flushMicrotasks();

          expect(tts.startReportingPositionCalls, 1);
          expect(tts.lastReporterBaseline, 0,
              reason: 'fresh play should install reporter with baseline=0',);
          expect(tts.lastReporterSpokenText, isNotNull,
              reason: 'fresh play should hand the chunk to the reporter',);

          playFuture.then((_) => cubit.close());
        });
      },
    );
  });
}
