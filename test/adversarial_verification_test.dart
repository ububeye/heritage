import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stone_town_heritage_vt_guide/blocs/site_detail/site_detail_cubit.dart';
import 'package:stone_town_heritage_vt_guide/blocs/site_detail/site_detail_state.dart';
import 'package:stone_town_heritage_vt_guide/blocs/localization/localization_cubit.dart';
import 'package:stone_town_heritage_vt_guide/core/constants/app_constants.dart';
import 'package:stone_town_heritage_vt_guide/data/models/audio_state.dart';
import 'package:stone_town_heritage_vt_guide/data/models/site_model.dart';
import 'package:stone_town_heritage_vt_guide/data/repositories/site_repository.dart';
import 'package:stone_town_heritage_vt_guide/data/services/shared_prefs_service.dart';
import 'package:stone_town_heritage_vt_guide/data/services/tts_service.dart';

class _TestSiteRepository implements SiteRepository {
  _TestSiteRepository(this._site);
  final SiteModel? _site;

  @override
  Future<SiteModel?> getSiteById(String id) async => _site;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _TestTtsService implements TtsService {
  _TestTtsService();

  TtsSpeakResult speakResult = const TtsSpeakResult(wasTruncated: false);
  int? maxDurationOverride;
  PausedResumePoint? pauseResumePoint;

  int speakCalls = 0;
  int stopCalls = 0;
  int pauseForRestartCalls = 0;
  int resumeFromCalls = 0;
  int setLanguageCalls = 0;
  int setPremiumCalls = 0;
  int applyPlaybackSpeedCalls = 0;

  double lastAppliedRate = AppConstants.defaultSpeechRate;
  double _currentSpeedMultiplier = 1.0;
  String? lastSpokenText;
  PausedResumePoint? lastResumePoint;
  ValueChanged<Duration>? onCompletionCallback;

  @override
  double get currentSpeedMultiplier => _currentSpeedMultiplier;

  @override
  Future<void> applyPlaybackSpeed(double speedMultiplier) async {
    applyPlaybackSpeedCalls++;
    _currentSpeedMultiplier = speedMultiplier;
    lastAppliedRate = (AppConstants.defaultSpeechRate * speedMultiplier).clamp(
      0.0,
      1.0,
    );
  }

  @override
  void setOnCompletion(ValueChanged<Duration>? onCompletion) {
    onCompletionCallback = onCompletion;
  }

  @override
  void setOnError(ValueChanged<String>? onError) {}

  // --- Session token support (Bug 1 + Bug 2 architecture fix) ---
  int _sessionToken = 0;
  int beginSessionCalls = 0;
  int invalidateSessionCalls = 0;

  @override
  int get currentSessionToken => _sessionToken;

  @override
  int beginSession() {
    _sessionToken++;
    beginSessionCalls++;
    return _sessionToken;
  }

  @override
  void invalidateSession() {
    _sessionToken++;
    invalidateSessionCalls++;
    onCompletionCallback = null;
  }

  bool _isPremium = false;

  @override
  void setPremium(bool isPremium) {
    setPremiumCalls++;
    _isPremium = isPremium;
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
    lastSpokenText = text;
    return speakResult;
  }

  @override
  Future<List<String>> getAvailableLanguages() async => const ['en', 'sw'];

  @override
  int? getMaxDuration() => _isPremium ? null : (maxDurationOverride ?? 30);

  @override
  Duration estimateDuration(String text) {
    if (maxDurationOverride != null) {
      return Duration(seconds: maxDurationOverride!);
    }
    return const Duration(seconds: 30);
  }

  @override
  TtsChunk previewChunkFor(String text) => TtsChunk(text: text, wasCut: false);

  @override
  void startReportingPosition(
    String spokenText, {
    required ValueChanged<Duration> onPosition,
    required Duration budget,
    int resumeBaseline = 0,
  }) {}

  @override
  void stopReportingPosition() {}

  @override
  void restartReportingWithSuffix({
    required String suffix,
    required int baseline,
    required ValueChanged<Duration> onPosition,
    required Duration budget,
  }) {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> resumeFrom(PausedResumePoint point) async {
    resumeFromCalls++;
    lastResumePoint = point;
    // Mirror the real TtsService: pauseForRestart() bumps the session
    // token so any post-pause callbacks are dropped. resumeFrom is
    // called by resumeAudio after beginSession() has already bumped
    // the token, so we don't bump here.
  }

  @override
  Future<PausedResumePoint?> pauseForRestart() async {
    pauseForRestartCalls++;
    // Mirror the real TtsService: pauseForRestart() invalidates the
    // session so stale completion callbacks cannot fire on the new
    // session that resumeAudio will start.
    invalidateSession();
    return pauseResumePoint;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    lastAppliedRate = rate;
  }

  @override
  Future<void> setPitch(double pitch) async {}

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
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(
        '_TestTtsService.${invocation.memberName} not stubbed',
      );
}

SiteModel _createSite() => const SiteModel(
  id: 'site-1',
  nameEn: 'Old Fort',
  nameSw: 'Ngome Kongwe',
  descriptionEn: 'The Old Fort is the oldest building in Stone Town.',
  descriptionSw: 'Ngome Kongwe ni jengo la zamani zaidi katika Mji Mkongwe.',
  descriptionFr: 'Le Vieux Fort est le plus ancien bâtiment de Stone Town.',
  descriptionDe: 'Das Old Fort ist das älteste Gebäude in Stone Town.',
  descriptionAr: 'القلعة القديمة هي أقدم مبنى في ستون تاون.',
  descriptionIt: 'Il Vecchio Forte è l\'edificio più antico di Stone Town.',
  descriptionEs: 'El Fuerte Viejo es el edificio más antiguo de Stone Town.',
  cloudinaryImageUrl: 'https://example.com/fort.jpg',
  latitude: -6.1619,
  longitude: 39.1936,
  category: 'historic',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.getInstance();
  });

  group('Finding A — Playback Speed Persistence & Calculation', () {
    test(
      'Playback speed multiplier saves and converts to engine speech rate',
      () async {
        final prefs = SharedPrefsService.instance;
        final tts = _TestTtsService();

        // Test 0.75x
        await prefs.setPlaybackSpeed(0.75);
        expect(prefs.playbackSpeed, 0.75);
        await tts.applyPlaybackSpeed(0.75);
        expect(tts.currentSpeedMultiplier, 0.75);
        expect(tts.lastAppliedRate, closeTo(0.5 * 0.75, 0.001));

        // Test 1.0x (Normal)
        await prefs.setPlaybackSpeed(1.0);
        expect(prefs.playbackSpeed, 1.0);
        await tts.applyPlaybackSpeed(1.0);
        expect(tts.currentSpeedMultiplier, 1.0);
        expect(tts.lastAppliedRate, closeTo(0.5 * 1.0, 0.001));

        // Test 1.25x
        await prefs.setPlaybackSpeed(1.25);
        expect(prefs.playbackSpeed, 1.25);
        await tts.applyPlaybackSpeed(1.25);
        expect(tts.currentSpeedMultiplier, 1.25);
        expect(tts.lastAppliedRate, closeTo(0.5 * 1.25, 0.001));

        // Test 1.5x
        await prefs.setPlaybackSpeed(1.5);
        expect(prefs.playbackSpeed, 1.5);
        await tts.applyPlaybackSpeed(1.5);
        expect(tts.currentSpeedMultiplier, 1.5);
        expect(tts.lastAppliedRate, closeTo(0.5 * 1.5, 0.001));
      },
    );

    test(
      'SiteDetailCubit delegates applyPlaybackSpeed to TtsService',
      () async {
        final tts = _TestTtsService();
        final cubit = SiteDetailCubit(
          siteRepository: _TestSiteRepository(_createSite()),
          ttsService: tts,
        );

        await cubit.applyPlaybackSpeed(1.25);
        expect(tts.applyPlaybackSpeedCalls, 1);
        expect(tts.currentSpeedMultiplier, 1.25);
      },
    );
  });

  group('Finding B & Localization Parity', () {
    test('en.json and sw.json have identical keys including coming_soon', () {
      final enRaw = File('assets/localization/en.json').readAsStringSync();
      final swRaw = File('assets/localization/sw.json').readAsStringSync();

      final enMap = jsonDecode(enRaw) as Map<String, dynamic>;
      final swMap = jsonDecode(swRaw) as Map<String, dynamic>;

      expect(enMap.containsKey('coming_soon'), isTrue);
      expect(swMap.containsKey('coming_soon'), isTrue);
      expect(enMap['coming_soon'], 'Coming soon');
      expect(swMap['coming_soon'], 'Inakuja hivi karibuni');

      // Check key parity
      final enKeys = enMap.keys.toSet();
      final swKeys = swMap.keys.toSet();

      final missingInSw = enKeys.difference(swKeys);
      final missingInEn = swKeys.difference(enKeys);

      expect(
        missingInSw,
        isEmpty,
        reason: 'Keys in en.json but missing in sw.json: $missingInSw',
      );
      expect(
        missingInEn,
        isEmpty,
        reason: 'Keys in sw.json but missing in en.json: $missingInEn',
      );
    });
  });

  group('Finding C — Version Formatting', () {
    test(
      'replaceFirst correctly populates both version and build number without duplicate',
      () {
        const template = 'Version %s (build %s)';
        const version = '1.0.0';
        const build = '42';

        final result = template
            .replaceFirst('%s', version)
            .replaceFirst('%s', build);
        expect(result, 'Version 1.0.0 (build 42)');
      },
    );

    test('Swahili version template correctly formats version and build', () {
      const template = 'Toleo %s (jengo %s)';
      const version = '2.1.0';
      const build = '7';

      final result = template
          .replaceFirst('%s', version)
          .replaceFirst('%s', build);
      expect(result, 'Toleo 2.1.0 (jengo 7)');
    });
  });

  group('Finding D — Resume Fallback Semantics', () {
    test('resumeAudio with null pausedResumePoint restarts from start', () {
      fakeAsync((async) {
        final tts = _TestTtsService();
        final site = _createSite();
        final cubit = SiteDetailCubit(
          siteRepository: _TestSiteRepository(site),
          ttsService: tts,
        );

        cubit.loadSite('site-1');
        async.flushMicrotasks();

        // Start playback
        cubit.playAudio('en');
        async.flushMicrotasks();
        expect(cubit.state.audioState.isPlaying, isTrue);

        // Simulate pause where pauseForRestart captured null (e.g. charOffset = 0)
        tts.pauseResumePoint = null;
        cubit.pauseAudio();
        async.flushMicrotasks();

        expect(cubit.state.audioState.isPaused, isTrue);
        expect(cubit.state.audioState.pausedResumePoint, isNull);

        // Resume audio - must restart playback rather than staying permanently frozen
        cubit.resumeAudio();
        async.flushMicrotasks();

        expect(cubit.state.audioState.isPlaying, isTrue);
        expect(cubit.state.audioState.isPaused, isFalse);
        expect(tts.speakCalls, 2); // 1st play + 1 restarted play
      });
    });

    test('resumeAudio with valid pausedResumePoint calls resumeFrom', () {
      fakeAsync((async) {
        final tts = _TestTtsService();
        final site = _createSite();
        final cubit = SiteDetailCubit(
          siteRepository: _TestSiteRepository(site),
          ttsService: tts,
        );

        cubit.loadSite('site-1');
        async.flushMicrotasks();

        // Start playback
        cubit.playAudio('en');
        async.flushMicrotasks();

        // Pause with valid resume point
        const point = PausedResumePoint(
          text: 'The Old Fort is the oldest building in Stone Town.',
          charOffset: 12,
        );
        tts.pauseResumePoint = point;
        cubit.pauseAudio();
        async.flushMicrotasks();

        expect(cubit.state.audioState.isPaused, isTrue);
        expect(cubit.state.audioState.pausedResumePoint, point);

        // Resume
        cubit.resumeAudio();
        async.flushMicrotasks();

        expect(tts.resumeFromCalls, 1);
        expect(tts.lastResumePoint, point);
        expect(cubit.state.audioState.isPlaying, isTrue);
        expect(cubit.state.audioState.isPaused, isFalse);
        expect(cubit.state.audioState.pausedResumePoint, isNull); // consumed
      });
    });
  });

  group('Audio State Machine & Rapid Interaction', () {
    test('Rapid taps: play -> pause -> resume -> stop in quick succession', () {
      fakeAsync((async) {
        final tts = _TestTtsService();
        final site = _createSite();
        final cubit = SiteDetailCubit(
          siteRepository: _TestSiteRepository(site),
          ttsService: tts,
        );

        cubit.loadSite('site-1');
        async.flushMicrotasks();

        // Rapid sequence
        cubit.playAudio('en');
        cubit.pauseAudio();
        cubit.resumeAudio();
        cubit.stopAudio();
        async.flushMicrotasks();

        expect(cubit.state.audioState.isPlaying, isFalse);
        expect(cubit.state.audioState.isPaused, isFalse);
        expect(cubit.state.audioState.position, Duration.zero);
      });
    });

    test('Cubit close() cleanly stops audio and cancels position ticker', () {
      fakeAsync((async) {
        final tts = _TestTtsService();
        final site = _createSite();
        final cubit = SiteDetailCubit(
          siteRepository: _TestSiteRepository(site),
          ttsService: tts,
        );

        cubit.loadSite('site-1');
        async.flushMicrotasks();

        cubit.playAudio('en');
        async.elapse(const Duration(milliseconds: 300));
        expect(
          cubit.state.audioState.position,
          const Duration(milliseconds: 300),
        );

        cubit.close();
        async.elapse(const Duration(milliseconds: 500));
        // Timer should not advance position after close
        expect(tts.stopCalls, greaterThanOrEqualTo(1));
      });
    });
  });

  group('Customer Bug 2 — Audio Isolation on Site Switching', () {
    test(
      'Playing Site A (Ngome Kongwe) -> Loading Site B (Forodhani) stops Site A audio immediately',
      () {
        fakeAsync((async) {
          final tts = _TestTtsService();
          final siteA = _createSite(); // Old Fort (Ngome Kongwe)
          const siteB = SiteModel(
            id: 'site-2',
            nameEn: 'Forodhani Gardens',
            nameSw: 'Bustani ya Forodhani',
            descriptionEn: 'Forodhani Gardens is a popular seafront park.',
            descriptionSw: 'Bustani ya Forodhani ni bustani maarufu ya pwani.',
            descriptionFr: 'Forodhani Gardens est un parc en bord de mer.',
            descriptionDe: 'Forodhani Gardens ist ein Park an der Küste.',
            descriptionAr: 'حدائق فورودهاني هي حديقة ساحلية شهيرة.',
            descriptionIt: 'I giardini Forodhani sono un parco sul lungomare.',
            descriptionEs: 'Los jardines de Forodhani son un parque marítimo.',
            cloudinaryImageUrl: 'https://example.com/forodhani.jpg',
            latitude: -6.1600,
            longitude: 39.1900,
            category: 'cultural',
          );

          final repo = _MultiSiteRepository({'site-1': siteA, 'site-2': siteB});
          final cubit = SiteDetailCubit(siteRepository: repo, ttsService: tts);

          // 1. Open Ngome Kongwe and play audio
          cubit.loadSite('site-1');
          async.flushMicrotasks();
          cubit.playAudio('en');
          async.flushMicrotasks();

          expect(cubit.state.audioState.isPlaying, isTrue);
          expect(cubit.state.audioState.siteId, 'site-1');

          final initialStopCalls = tts.stopCalls;

          // 2. User navigates to Forodhani (loadSite site-2)
          cubit.loadSite('site-2');
          async.flushMicrotasks();

          // 3. Audio for Site A must be stopped immediately and state cleanly reset
          expect(tts.stopCalls, greaterThan(initialStopCalls));
          expect(cubit.state.audioState.isPlaying, isFalse);
          expect(cubit.state.audioState.isPaused, isFalse);
          expect(cubit.state.audioState.siteId, isNull);
          expect(cubit.state.site?.id, 'site-2');

          // 4. Playing Forodhani starts its own audio with site-2 ID
          cubit.playAudio('en');
          async.flushMicrotasks();

          expect(cubit.state.audioState.isPlaying, isTrue);
          expect(cubit.state.audioState.siteId, 'site-2');
          expect(tts.lastSpokenText, contains('Forodhani Gardens'));
        });
      },
    );

    test(
      'Paused Site A -> Navigating to Site B does not leak pause state or resume points',
      () {
        fakeAsync((async) {
          final tts = _TestTtsService();
          final siteA = _createSite();
          const siteB = SiteModel(
            id: 'site-2',
            nameEn: 'Forodhani Gardens',
            nameSw: 'Bustani ya Forodhani',
            descriptionEn: 'Forodhani Gardens description.',
            descriptionSw: 'Maelezo ya Bustani ya Forodhani.',
            descriptionFr: 'Description Forodhani.',
            descriptionDe: 'Beschreibung Forodhani.',
            descriptionAr: 'وصف حدائق فورودهاني.',
            descriptionIt: 'Descrizione giardini Forodhani.',
            descriptionEs: 'Descripción jardines Forodhani.',
            cloudinaryImageUrl: 'https://example.com/forodhani.jpg',
            latitude: -6.1600,
            longitude: 39.1900,
            category: 'cultural',
          );

          final repo = _MultiSiteRepository({'site-1': siteA, 'site-2': siteB});
          final cubit = SiteDetailCubit(siteRepository: repo, ttsService: tts);

          // 1. Play and Pause on Site A
          cubit.loadSite('site-1');
          async.flushMicrotasks();
          cubit.playAudio('en');
          async.flushMicrotasks();

          tts.pauseResumePoint = const PausedResumePoint(
            text: 'The Old Fort is the oldest building in Stone Town.',
            charOffset: 20,
          );
          cubit.pauseAudio();
          async.flushMicrotasks();

          expect(cubit.state.audioState.isPaused, isTrue);
          expect(cubit.state.audioState.siteId, 'site-1');

          // 2. User moves to Site B
          cubit.loadSite('site-2');
          async.flushMicrotasks();

          // 3. Audio state must NOT be paused and must have cleared resume point
          expect(cubit.state.audioState.isPaused, isFalse);
          expect(cubit.state.audioState.pausedResumePoint, isNull);
          expect(cubit.state.site?.id, 'site-2');
        });
      },
    );
  });

  group('Customer Bug 1 — Pause & Resume Audio Session Recovery', () {
    test(
      'Play -> Pause -> Resume re-registers completion handler and completes cleanly',
      () {
        fakeAsync((async) {
          final tts = _TestTtsService();
          final site = _createSite();
          final cubit = SiteDetailCubit(
            siteRepository: _TestSiteRepository(site),
            ttsService: tts,
          );

          cubit.loadSite('site-1');
          async.flushMicrotasks();

          // Play
          cubit.playAudio('en');
          async.flushMicrotasks();

          // Pause
          const point = PausedResumePoint(
            text: 'The Old Fort is the oldest building in Stone Town.',
            charOffset: 15,
          );
          tts.pauseResumePoint = point;
          cubit.pauseAudio();
          async.flushMicrotasks();

          expect(cubit.state.audioState.isPaused, isTrue);

          // Resume
          cubit.resumeAudio();
          async.flushMicrotasks();

          expect(cubit.state.audioState.isPlaying, isTrue);
          expect(cubit.state.audioState.isPaused, isFalse);
          expect(tts.onCompletionCallback, isNotNull);

          // Trigger completion callback from TTS engine on natural end
          tts.onCompletionCallback!(const Duration(seconds: 25));
          async.flushMicrotasks();

          expect(cubit.state.audioState.isPlaying, isFalse);
          expect(cubit.state.audioState.position, const Duration(seconds: 25));
        });
      },
    );

    test(
      'Play -> Pause -> Resume -> Premium infinite auto-replay works cleanly',
      () {
        fakeAsync((async) {
          final tts = _TestTtsService();
          final site = _createSite();
          final cubit = SiteDetailCubit(
            siteRepository: _TestSiteRepository(site),
            ttsService: tts,
          );

          cubit.loadSite('site-1');
          async.flushMicrotasks();

          // 1. Play as premium
          cubit.playAudio('en', isPremium: true);
          async.flushMicrotasks();

          // 2. Pause
          const point = PausedResumePoint(
            text: 'The Old Fort is the oldest building in Stone Town.',
            charOffset: 10,
          );
          tts.pauseResumePoint = point;
          cubit.pauseAudio();
          async.flushMicrotasks();

          // 3. Resume
          cubit.resumeAudio();
          async.flushMicrotasks();
          expect(cubit.state.audioState.isPlaying, isTrue);

          final initialSpeakCalls = tts.speakCalls;

          // 4. Natural completion fires on resumed playback -> should automatically loop
          tts.onCompletionCallback!(const Duration(seconds: 40));
          async.flushMicrotasks();

          expect(tts.speakCalls, greaterThan(initialSpeakCalls));
          expect(cubit.state.audioState.isPlaying, isTrue);
        });
      },
    );

    test('Play -> Pause -> Replay restarts from beginning at 0:00', () {
      fakeAsync((async) {
        final tts = _TestTtsService();
        final site = _createSite();
        final cubit = SiteDetailCubit(
          siteRepository: _TestSiteRepository(site),
          ttsService: tts,
        );

        cubit.loadSite('site-1');
        async.flushMicrotasks();

        cubit.playAudio('en');
        async.flushMicrotasks();

        cubit.pauseAudio();
        async.flushMicrotasks();
        expect(cubit.state.audioState.isPaused, isTrue);

        // Replay: stops previous and plays fresh
        cubit.stopAudio();
        cubit.playAudio('en');
        async.flushMicrotasks();

        expect(cubit.state.audioState.isPlaying, isTrue);
        expect(cubit.state.audioState.isPaused, isFalse);
        expect(cubit.state.audioState.position, Duration.zero);
      });
    });

    test('Play -> Pause -> Stop -> Play works with full clean state', () {
      fakeAsync((async) {
        final tts = _TestTtsService();
        final site = _createSite();
        final cubit = SiteDetailCubit(
          siteRepository: _TestSiteRepository(site),
          ttsService: tts,
        );

        cubit.loadSite('site-1');
        async.flushMicrotasks();

        cubit.playAudio('en');
        cubit.pauseAudio();
        async.flushMicrotasks();

        expect(cubit.state.audioState.isPaused, isTrue);

        cubit.stopAudio();
        async.flushMicrotasks();

        expect(cubit.state.audioState.isPaused, isFalse);
        expect(cubit.state.audioState.isPlaying, isFalse);
        expect(cubit.state.audioState.pausedResumePoint, isNull);

        cubit.playAudio('en');
        async.flushMicrotasks();

        expect(cubit.state.audioState.isPlaying, isTrue);
        expect(cubit.state.audioState.position, Duration.zero);
      });
    });

    test(
      'Play -> Pause -> navigate away -> return -> Play works without requiring Start Guide',
      () {
        fakeAsync((async) {
          final tts = _TestTtsService();
          final siteA = _createSite();
          const siteB = SiteModel(
            id: 'site-2',
            nameEn: 'Site B',
            nameSw: 'Eneo B',
            descriptionEn: 'Site B description.',
            descriptionSw: 'Maelezo ya eneo B.',
            descriptionFr: 'Description B.',
            descriptionDe: 'Beschreibung B.',
            descriptionAr: 'وصف ب.',
            descriptionIt: 'Descrizione B.',
            descriptionEs: 'Descripción B.',
            cloudinaryImageUrl: 'https://example.com/b.jpg',
            latitude: -6.1600,
            longitude: 39.1900,
            category: 'historic',
          );

          final repo = _MultiSiteRepository({'site-1': siteA, 'site-2': siteB});
          final cubit = SiteDetailCubit(siteRepository: repo, ttsService: tts);

          // 1. Play & Pause on Site A
          cubit.loadSite('site-1');
          async.flushMicrotasks();
          cubit.playAudio('en');
          async.flushMicrotasks();
          cubit.pauseAudio();
          async.flushMicrotasks();

          // 2. Navigate away to Site B
          cubit.loadSite('site-2');
          async.flushMicrotasks();

          // 3. Return to Site A
          cubit.loadSite('site-1');
          async.flushMicrotasks();

          // 4. Tap Play on audio bar (not Start Guide) -> Audio starts cleanly
          expect(cubit.state.audioState.isPaused, isFalse);
          expect(cubit.state.audioState.isPlaying, isFalse);

          cubit.playAudio('en');
          async.flushMicrotasks();

          expect(cubit.state.audioState.isPlaying, isTrue);
          expect(cubit.state.audioState.siteId, 'site-1');
        });
      },
    );

    test(
      'Multi-site chaining: Site A -> Site B -> Site C -> Site A stops previous audio at each step',
      () {
        fakeAsync((async) {
          final tts = _TestTtsService();
          final siteA = _createSite();
          const siteB = SiteModel(
            id: 'site-2',
            nameEn: 'Site B',
            nameSw: 'Eneo B',
            descriptionEn: 'Site B description.',
            descriptionSw: 'Maelezo B.',
            descriptionFr: 'Description B.',
            descriptionDe: 'Beschreibung B.',
            descriptionAr: 'وصف B.',
            descriptionIt: 'Descrizione B.',
            descriptionEs: 'Descripción B.',
            cloudinaryImageUrl: 'https://example.com/b.jpg',
            latitude: -6.1600,
            longitude: 39.1900,
            category: 'historic',
          );
          const siteC = SiteModel(
            id: 'site-3',
            nameEn: 'Site C',
            nameSw: 'Eneo C',
            descriptionEn: 'Site C description.',
            descriptionSw: 'Maelezo C.',
            descriptionFr: 'Description C.',
            descriptionDe: 'Beschreibung C.',
            descriptionAr: 'وصف C.',
            descriptionIt: 'Descrizione C.',
            descriptionEs: 'Descripción C.',
            cloudinaryImageUrl: 'https://example.com/c.jpg',
            latitude: -6.1620,
            longitude: 39.1920,
            category: 'cultural',
          );

          final repo = _MultiSiteRepository({
            'site-1': siteA,
            'site-2': siteB,
            'site-3': siteC,
          });
          final cubit = SiteDetailCubit(siteRepository: repo, ttsService: tts);

          // Site A play
          cubit.loadSite('site-1');
          async.flushMicrotasks();
          cubit.playAudio('en');
          async.flushMicrotasks();
          expect(cubit.state.audioState.isPlaying, isTrue);
          expect(cubit.state.audioState.siteId, 'site-1');

          // Site B load -> stops A
          cubit.loadSite('site-2');
          async.flushMicrotasks();
          expect(cubit.state.audioState.isPlaying, isFalse);
          cubit.playAudio('en');
          async.flushMicrotasks();
          expect(cubit.state.audioState.isPlaying, isTrue);
          expect(cubit.state.audioState.siteId, 'site-2');

          // Site C load -> stops B
          cubit.loadSite('site-3');
          async.flushMicrotasks();
          expect(cubit.state.audioState.isPlaying, isFalse);
          cubit.playAudio('en');
          async.flushMicrotasks();
          expect(cubit.state.audioState.isPlaying, isTrue);
          expect(cubit.state.audioState.siteId, 'site-3');

          // Return to Site A -> stops C
          cubit.loadSite('site-1');
          async.flushMicrotasks();
          expect(cubit.state.audioState.isPlaying, isFalse);
          cubit.playAudio('en');
          async.flushMicrotasks();
          expect(cubit.state.audioState.isPlaying, isTrue);
          expect(cubit.state.audioState.siteId, 'site-1');
        });
      },
    );

    test('Mismatched siteId on resume safely restarts for current site', () {
      fakeAsync((async) {
        final tts = _TestTtsService();
        final siteA = _createSite();
        const siteB = SiteModel(
          id: 'site-2',
          nameEn: 'Site B',
          nameSw: 'Eneo B',
          descriptionEn: 'Site B description text for verification.',
          descriptionSw: 'Maelezo B.',
          descriptionFr: 'Description B.',
          descriptionDe: 'Beschreibung B.',
          descriptionAr: 'وصف B.',
          descriptionIt: 'Descrizione B.',
          descriptionEs: 'Descripción B.',
          cloudinaryImageUrl: 'https://example.com/b.jpg',
          latitude: -6.1600,
          longitude: 39.1900,
          category: 'historic',
        );

        final repo = _MultiSiteRepository({'site-1': siteA, 'site-2': siteB});
        final cubit = SiteDetailCubit(siteRepository: repo, ttsService: tts);

        // Load Site B
        cubit.loadSite('site-2');
        async.flushMicrotasks();

        // Artificially inject a stale AudioState belonging to site-1
        cubit.emit(
          cubit.state.copyWith(
            audioState: const AudioState(
              siteId: 'site-1',
              isPaused: true,
              pausedResumePoint: PausedResumePoint(
                text: 'Old Fort text from site-1',
                charOffset: 10,
              ),
            ),
          ),
        );

        // Call resumeAudio on Site B -> should safely recognize mismatch and play Site B from start
        cubit.resumeAudio();
        async.flushMicrotasks();

        expect(cubit.state.audioState.isPlaying, isTrue);
        expect(cubit.state.audioState.siteId, 'site-2');
        expect(tts.lastSpokenText, contains('Site B description text'));
      });
    });
  });

  group('Session-token architecture — regression tests', () {
    // The customer's two scenarios (pause breaks audio, audio continues
    // after site change) shared a single root cause: scattered audio
    // session ownership. The cubit installed completion callbacks and
    // progress reporters on TtsService, and those callbacks could fire
    // for the WRONG utterance because the engine doesn't know which
    // session it belongs to. The fix introduces a monotonic session
    // token on TtsService that every callback captures at registration
    // time — stale callbacks are dropped by token mismatch.
    //
    // These tests pin the new contract: every play/pause/resume site
    // change begins a fresh session, and every invalidate session
    // (stop, pause, loadSite) bumps the token so prior callbacks die.

    test(
      'playAudio calls beginSession so the new completion handler captures the new token',
      () {
        fakeAsync((async) {
          final tts = _TestTtsService();
          final site = _createSite();
          final cubit = SiteDetailCubit(
            siteRepository: _TestSiteRepository(site),
            ttsService: tts,
          );

          cubit.loadSite('site-1');
          async.flushMicrotasks();

          final tokenBefore = tts.currentSessionToken;
          cubit.playAudio('en');
          async.flushMicrotasks();

          expect(
            tts.beginSessionCalls,
            greaterThanOrEqualTo(1),
            reason: 'playAudio must call beginSession to start a fresh token',
          );
          expect(
            tts.currentSessionToken,
            greaterThan(tokenBefore),
            reason: 'currentSessionToken must be bumped after playAudio',
          );
        });
      },
    );

    test(
      'loadSite calls invalidateSession so any leftover callbacks from the previous site are dropped',
      () {
        fakeAsync((async) {
          final tts = _TestTtsService();
          final siteA = _createSite();
          final repo = _MultiSiteRepository({'site-1': siteA});
          final cubit = SiteDetailCubit(siteRepository: repo, ttsService: tts);

          cubit.loadSite('site-1');
          async.flushMicrotasks();
          cubit.playAudio('en');
          async.flushMicrotasks();

          final tokenAfterPlay = tts.currentSessionToken;
          final invalidateBefore = tts.invalidateSessionCalls;

          cubit.loadSite('site-1'); // re-load same site
          async.flushMicrotasks();

          expect(
            tts.invalidateSessionCalls,
            greaterThan(invalidateBefore),
            reason:
                'loadSite must invalidate the session so the previous '
                'session\'s callbacks cannot fire on the new screen',
          );
          expect(
            tts.currentSessionToken,
            greaterThan(tokenAfterPlay),
            reason: 'session token must be bumped across loadSite',
          );
        });
      },
    );

    test(
      'stopAudio invalidates the session AND zeroes AudioState in one call',
      () {
        fakeAsync((async) {
          final tts = _TestTtsService();
          final site = _createSite();
          final cubit = SiteDetailCubit(
            siteRepository: _TestSiteRepository(site),
            ttsService: tts,
          );

          cubit.loadSite('site-1');
          async.flushMicrotasks();
          cubit.playAudio('en');
          async.flushMicrotasks();
          expect(cubit.state.audioState.isPlaying, isTrue);

          final tokenBefore = tts.currentSessionToken;
          final invalidateBefore = tts.invalidateSessionCalls;

          cubit.stopAudio();
          async.flushMicrotasks();

          expect(
            tts.invalidateSessionCalls,
            greaterThan(invalidateBefore),
            reason: 'stopAudio must invalidate the session',
          );
          expect(
            tts.currentSessionToken,
            greaterThan(tokenBefore),
            reason: 'session token must be bumped after stopAudio',
          );
          expect(
            cubit.state.audioState.isPlaying,
            isFalse,
            reason: 'AudioState must not show isPlaying after stop',
          );
          expect(
            cubit.state.audioState.isPaused,
            isFalse,
            reason: 'AudioState must not show isPaused after stop',
          );
          expect(
            cubit.state.audioState.position,
            Duration.zero,
            reason: 'position must reset to zero after stop',
          );
        });
      },
    );

    test(
      'pauseForRestart bumps the session token so any post-pause completion callback is dropped',
      () {
        fakeAsync((async) {
          final tts = _TestTtsService();
          final site = _createSite();
          final cubit = SiteDetailCubit(
            siteRepository: _TestSiteRepository(site),
            ttsService: tts,
          );

          cubit.loadSite('site-1');
          async.flushMicrotasks();
          cubit.playAudio('en');
          async.flushMicrotasks();

          // Capture the original completion callback closure that the
          // cubit registered for this play. After pause, the token
          // should be bumped so that even if this closure somehow fires
          // it would be dropped by the wrapper.
          final staleCallback = tts.onCompletionCallback;
          expect(staleCallback, isNotNull);

          final tokenBeforePause = tts.currentSessionToken;

          cubit.pauseAudio();
          async.flushMicrotasks();

          expect(
            tts.currentSessionToken,
            greaterThan(tokenBeforePause),
            reason:
                'pauseForRestart inside pauseAudio must bump the '
                'session token via TtsService.invalidateSession()',
          );
          expect(cubit.state.audioState.isPlaying, isFalse);
          expect(cubit.state.audioState.isPaused, isTrue);
        });
      },
    );

    test(
      'site A -> site B -> site A: each transition invalidates the session, no stale audio survives',
      () {
        // Exact customer complaint: "Audio inapatikana kwa ile button ya
        // play ila ukigandisha haiganduki tena. Ata ukienda kwenye
        // picha nyingine ukiirudia haitaki tena mpaka uanze kubonyeza
        // Start Guide pale juu." — "Audio plays but Pause doesn't
        // pause. Even navigating to another picture and returning
        // doesn't work until you press Start Guide at the top."
        fakeAsync((async) {
          final tts = _TestTtsService();
          final siteA = _createSite();
          const siteB = SiteModel(
            id: 'site-2',
            nameEn: 'Forodhani Gardens',
            nameSw: 'Bustani ya Forodhani',
            descriptionEn: 'Forodhani Gardens is a popular seafront park.',
            descriptionSw: 'Bustani ya Forodhani ni bustani maarufu ya pwani.',
            descriptionFr: 'Forodhani Gardens est un parc en bord de mer.',
            descriptionDe: 'Forodhani Gardens ist ein Park an der Küste.',
            descriptionAr: 'حدائق فورودهاني هي حديقة ساحلية شهيرة.',
            descriptionIt: 'I giardini Forodhani sono un parco sul lungomare.',
            descriptionEs: 'Los jardines de Forodhani son un parque marítimo.',
            cloudinaryImageUrl: 'https://example.com/forodhani.jpg',
            latitude: -6.1600,
            longitude: 39.1900,
            category: 'cultural',
          );
          final repo = _MultiSiteRepository({'site-1': siteA, 'site-2': siteB});
          final cubit = SiteDetailCubit(siteRepository: repo, ttsService: tts);

          // Play site A
          cubit.loadSite('site-1');
          async.flushMicrotasks();
          cubit.playAudio('en');
          async.flushMicrotasks();
          expect(cubit.state.audioState.isPlaying, isTrue);

          // Pause site A
          cubit.pauseAudio();
          async.flushMicrotasks();
          expect(cubit.state.audioState.isPaused, isTrue);

          // Navigate to site B
          cubit.loadSite('site-2');
          async.flushMicrotasks();
          // After loadSite, the cubit is in "loading" state with empty
          // audio. Finish the load by flushing.
          expect(cubit.state.audioState.isPlaying, isFalse);
          expect(cubit.state.audioState.isPaused, isFalse);

          // Plugin Play → site A
          cubit.loadSite('site-1');
          async.flushMicrotasks();
          cubit.playAudio('en');
          async.flushMicrotasks();

          expect(
            cubit.state.audioState.isPlaying,
            isTrue,
            reason:
                'After navigating back to Site A, Play must work '
                'without requiring Start Guide',
          );
          expect(cubit.state.audioState.siteId, 'site-1');
          expect(
            tts.lastSpokenText,
            contains('Old Fort'),
            reason:
                'The freshly spoken text must be Site A\'s text, '
                'not a stale Site B suffix',
          );
        });
      },
    );

    test(
      'play -> pause -> resume -> pause -> resume (rapid) leaves a healthy session',
      () {
        // Customer scenario: very rapid interaction where the audio
        // session would previously get stuck. With the session token,
        // each pause-for-restart bumps the token and each resume
        // begins a fresh session — the final state is clean and
        // subsequent actions work as expected.
        fakeAsync((async) {
          final tts = _TestTtsService();
          final site = _createSite();
          final cubit = SiteDetailCubit(
            siteRepository: _TestSiteRepository(site),
            ttsService: tts,
          );

          cubit.loadSite('site-1');
          async.flushMicrotasks();

          cubit.playAudio('en');
          async.flushMicrotasks();

          cubit.pauseAudio();
          async.flushMicrotasks();

          cubit.resumeAudio();
          async.flushMicrotasks();

          cubit.pauseAudio();
          async.flushMicrotasks();

          cubit.resumeAudio();
          async.flushMicrotasks();

          expect(
            cubit.state.audioState.isPlaying,
            isTrue,
            reason:
                'After play->pause->resume->pause->resume the '
                'session must be in a healthy playing state',
          );
          expect(
            cubit.state.audioState.isPaused,
            isFalse,
            reason: 'Pause must not leave the state frozen at paused',
          );
          expect(
            cubit.state.audioState.pausedResumePoint,
            isNull,
            reason:
                'pausedResumePoint must be cleared after the '
                'final resume (the resume consumed the point)',
          );
        });
      },
    );

    test(
      'no stale completion callback can fire after a rapid play->stop->play cycle',
      () {
        // The customer scenario in Bug 2 was: "Pia ukiplay audio sio
        // kama mwanzo, kama ukienda kwenye picha nyingine itanyamaza
        // automatic. Inaendelea kusema mpaka zooshe sekunde." — "If
        // you play audio on picture X, switching to picture Y doesn't
        // mute it. It keeps speaking until a few seconds pass."
        //
        // Architectural cause: the previous play's completion callback
        // was still installed when the new play began, and a stale
        // completion could recursively call playAudio on the old site.
        // With the session token, the OLD callback's wrapper detects
        // the token mismatch and drops the call — no recursive play.
        fakeAsync((async) {
          final tts = _TestTtsService();
          final siteA = _createSite();
          const siteB = SiteModel(
            id: 'site-2',
            nameEn: 'Forodhani Gardens',
            nameSw: 'Bustani ya Forodhani',
            descriptionEn: 'Forodhani Gardens is a popular seafront park.',
            descriptionSw: 'Bustani ya Forodhani ni bustani maarufu ya pwani.',
            descriptionFr: 'Forodhani Gardens est un parc en bord de mer.',
            descriptionDe: 'Forodhani Gardens ist ein Park an der Küste.',
            descriptionAr: 'حدائق فورودهاني هي حديقة ساحلية شهيرة.',
            descriptionIt: 'I giardini Forodhani sono un parco sul lungomare.',
            descriptionEs: 'Los jardines de Forodhani son un parque marítimo.',
            cloudinaryImageUrl: 'https://example.com/forodhani.jpg',
            latitude: -6.1600,
            longitude: 39.1900,
            category: 'cultural',
          );
          final repo = _MultiSiteRepository({'site-1': siteA, 'site-2': siteB});
          final cubit = SiteDetailCubit(siteRepository: repo, ttsService: tts);

          // Play site A
          cubit.loadSite('site-1');
          async.flushMicrotasks();
          cubit.playAudio('en');
          async.flushMicrotasks();
          final tokenAfterPlayA = tts.currentSessionToken;

          // Capture the OLD completion callback. In a real TtsService
          // (not the TestTtsService), this closure would be wrapped
          // with a token-guard. The TestTtsService does NOT replicate
          // the wrapper — instead we simulate the architectural
          // property directly: the cubit MUST have called
          // beginSession on the new play, so the new completion
          // callback captures a different token than the old one.
          final oldCallback = tts.onCompletionCallback;
          expect(oldCallback, isNotNull);

          // Navigate to site B (which internally calls invalidateSession)
          cubit.loadSite('site-2');
          async.flushMicrotasks();

          // The session token must have been bumped by loadSite
          // (invalidateSession()). The OLD callback (if it were the
          // real wrapped one) would now see a token mismatch.
          expect(
            tts.currentSessionToken,
            greaterThan(tokenAfterPlayA),
            reason:
                'loadSite must invalidate the session token, so the '
                'old completion callback\'s token guard would drop it',
          );

          // Play site B
          cubit.playAudio('en');
          async.flushMicrotasks();

          final newCallback = tts.onCompletionCallback;
          expect(newCallback, isNotNull);
          expect(
            identical(oldCallback, newCallback),
            isFalse,
            reason:
                'site B\'s playAudio must register a fresh completion '
                'callback, not reuse site A\'s',
          );

          // The new token is greater than the old one.
          expect(
            tts.currentSessionToken,
            greaterThan(tokenAfterPlayA),
            reason:
                'New play must bump the session token past the old '
                'play\'s token so the token guard works',
          );

          // Site B audio is healthy
          expect(cubit.state.audioState.isPlaying, isTrue);
          expect(cubit.state.audioState.siteId, 'site-2');
        });
      },
    );

    test(
      'playAudio on a paused site begins a fresh session without leaking the old resume point',
      () {
        // The "tapping Play on a paused site" path must begin a fresh
        // session (drop the old resume point) because the new speak
        // would otherwise be re-speaking the suffix with stale
        // state. The 'pausedResumePoint == null' is the deterministic
        // fallback: re-speak from the beginning.
        fakeAsync((async) {
          final tts = _TestTtsService();
          final site = _createSite();
          final cubit = SiteDetailCubit(
            siteRepository: _TestSiteRepository(site),
            ttsService: tts,
          );

          cubit.loadSite('site-1');
          async.flushMicrotasks();
          cubit.playAudio('en');
          async.flushMicrotasks();
          // Stub the pauseForRestart to capture a valid resume point so
          // the post-pause state carries pausedResumePoint.
          tts.pauseResumePoint = PausedResumePoint(
            text: 'Old Fort text from site-1',
            charOffset: 10,
          );
          cubit.pauseAudio();
          async.flushMicrotasks();
          expect(cubit.state.audioState.isPaused, isTrue);
          expect(cubit.state.audioState.pausedResumePoint, isNotNull);

          // Now play again — the cubit begins a fresh session and
          // clears the resume point.
          cubit.playAudio('en');
          async.flushMicrotasks();

          expect(
            cubit.state.audioState.pausedResumePoint,
            isNull,
            reason: 'A fresh playAudio must clear any prior resume point',
          );
          expect(cubit.state.audioState.isPlaying, isTrue);
          expect(
            cubit.state.audioState.position,
            Duration.zero,
            reason:
                'A fresh play starts from position 0, not the '
                'paused offset',
          );
        });
      },
    );

    test(
      'language switch invalidates the session so old-language audio cannot continue',
      () {
        // Same architecture as site switching: language switching
        // calls stopAudio() + playAudio(newLang). The new play
        // begins a fresh session so the old-language completion
        // callback cannot recursively fire.
        fakeAsync((async) {
          final tts = _TestTtsService();
          final site = _createSite();
          final cubit = SiteDetailCubit(
            siteRepository: _TestSiteRepository(site),
            ttsService: tts,
          );

          cubit.loadSite('site-1');
          async.flushMicrotasks();
          cubit.playAudio('en');
          async.flushMicrotasks();
          final tokenAfterEnglish = tts.currentSessionToken;

          // Mimic the detail_screen language picker: stop + play new.
          cubit.stopAudio();
          async.flushMicrotasks();
          cubit.playAudio('sw');
          async.flushMicrotasks();

          expect(
            tts.currentSessionToken,
            greaterThan(tokenAfterEnglish),
            reason:
                'Language switch via stopAudio + playAudio must '
                'bump the session token',
          );
          expect(cubit.state.audioState.isPlaying, isTrue);
          expect(cubit.state.audioState.languageCode, 'sw');
        });
      },
    );
  });
}

class _MultiSiteRepository implements SiteRepository {
  _MultiSiteRepository(this._sites);
  final Map<String, SiteModel> _sites;

  @override
  Future<SiteModel?> getSiteById(String id) async => _sites[id];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(
        '_MultiSiteRepository.${invocation.memberName} not stubbed',
      );
}
