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
    lastAppliedRate = (AppConstants.defaultSpeechRate * speedMultiplier).clamp(0.0, 1.0);
  }

  @override
  void setOnCompletion(ValueChanged<Duration>? onCompletion) {
    onCompletionCallback = onCompletion;
  }

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
    lastSpokenText = text;
    return speakResult;
  }

  @override
  Future<List<String>> getAvailableLanguages() async => const ['en', 'sw'];

  @override
  int? getMaxDuration() => maxDurationOverride ?? 30;

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
  }

  @override
  Future<PausedResumePoint?> pauseForRestart() async {
    pauseForRestartCalls++;
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
      throw UnimplementedError('_TestTtsService.${invocation.memberName} not stubbed');
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
    test('Playback speed multiplier saves and converts to engine speech rate', () async {
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
    });

    test('SiteDetailCubit delegates applyPlaybackSpeed to TtsService', () async {
      final tts = _TestTtsService();
      final cubit = SiteDetailCubit(
        siteRepository: _TestSiteRepository(_createSite()),
        ttsService: tts,
      );

      await cubit.applyPlaybackSpeed(1.25);
      expect(tts.applyPlaybackSpeedCalls, 1);
      expect(tts.currentSpeedMultiplier, 1.25);
    });
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

      expect(missingInSw, isEmpty, reason: 'Keys in en.json but missing in sw.json: $missingInSw');
      expect(missingInEn, isEmpty, reason: 'Keys in sw.json but missing in en.json: $missingInEn');
    });
  });

  group('Finding C — Version Formatting', () {
    test('replaceFirst correctly populates both version and build number without duplicate', () {
      const template = 'Version %s (build %s)';
      const version = '1.0.0';
      const build = '42';

      final result = template.replaceFirst('%s', version).replaceFirst('%s', build);
      expect(result, 'Version 1.0.0 (build 42)');
    });

    test('Swahili version template correctly formats version and build', () {
      const template = 'Toleo %s (jengo %s)';
      const version = '2.1.0';
      const build = '7';

      final result = template.replaceFirst('%s', version).replaceFirst('%s', build);
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
        expect(cubit.state.audioState.position, const Duration(milliseconds: 300));

        cubit.close();
        async.elapse(const Duration(milliseconds: 500));
        // Timer should not advance position after close
        expect(tts.stopCalls, greaterThanOrEqualTo(1));
      });
    });
  });

  group('Customer Bug 2 — Audio Isolation on Site Switching', () {
    test('Playing Site A (Ngome Kongwe) -> Loading Site B (Forodhani) stops Site A audio immediately', () {
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
    });

    test('Paused Site A -> Navigating to Site B does not leak pause state or resume points', () {
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
    });
  });

  group('Customer Bug 1 — Pause & Resume Audio Session Recovery', () {
    test('Play -> Pause -> Resume re-registers completion handler and completes cleanly', () {
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
    });

    test('Play -> Pause -> navigate away -> return -> Play works without requiring Start Guide', () {
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
    });
  });
}

class _MultiSiteRepository implements SiteRepository {
  _MultiSiteRepository(this._sites);
  final Map<String, SiteModel> _sites;

  @override
  Future<SiteModel?> getSiteById(String id) async => _sites[id];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_MultiSiteRepository.${invocation.memberName} not stubbed');
}
