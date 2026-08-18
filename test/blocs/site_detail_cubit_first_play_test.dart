// Tests that SiteDetailCubit flips the SharedPreferences flag
// `audioPreviewedAtLeastOnce` to true after the first successful
// `playAudio` call. The login / register gates read this flag to
// decide whether to show the post-login value-prop screen.

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

/// Minimal `TtsService` fake that records nothing but provides the
/// non-null return contract the cubit needs from `speak()`,
/// `previewChunkFor`, `getMaxDuration`, and `estimateDuration`.
class _FakeTtsService implements TtsService {
  @override
  TtsChunk previewChunkFor(String text) =>
      TtsChunk(text: text, wasCut: false);

  @override
  Future<TtsSpeakResult> speak(
    String text, {
    String? languageCode,
    TtsChunk? precomputedChunk,
  }) async =>
      const TtsSpeakResult(wasTruncated: false);

  @override
  int? getMaxDuration() => 30;

  @override
  Duration estimateDuration(String text) => const Duration(seconds: 30);

  @override
  void setPremium(bool isPremium) {}

  @override
  Future<SetLanguageOutcome> setLanguage(String languageCode) async =>
      SetLanguageOutcome.ok;

  @override
  int get currentSessionToken => 0;

  @override
  int beginSession() => 0;

  @override
  void invalidateSession() {}

  @override
  void setOnError(ValueChanged<String>? onError) {}

  @override
  void setOnCompletion(ValueChanged<Duration>? onCompletion) {}

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
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> resumeFrom(PausedResumePoint point) async {}

  @override
  Future<PausedResumePoint?> pauseForRestart() async => null;

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> applyPlaybackSpeed(double speedMultiplier) async {}

  @override
  double get currentSpeedMultiplier => 1.0;

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
  Future<List<String>> getAvailableLanguages() async => const ['en'];

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_FakeTtsService.${invocation.memberName} not stubbed',
    );
  }
}

class _NoopLocalizationCubit extends LocalizationCubit {
  _NoopLocalizationCubit() : super(ttsService: _FakeTtsService());
}

SiteModel _makeSite() {
  const description =
      'A short description for the audio playback test, just enough '
      'text to exercise the chunker honestly without needing a real '
      'transcript.';
  return SiteModel(
    id: 'site-1',
    nameEn: 'Test Site',
    nameSw: 'Tovuti ya Mtihani',
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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.getInstance();
  });

  setUp(() {
    // Reset the flag between tests so each starts from a known state.
    SharedPreferences.setMockInitialValues({});
  });

  test(
      'first successful playAudio sets audioPreviewedAtLeastOnce to true',
      () async {
    final prefs = await SharedPrefsService.getInstance();
    expect(prefs.audioPreviewedAtLeastOnce, isFalse);

    SiteDetailCubit? cubit;
    fakeAsync((async) {
      cubit = SiteDetailCubit(
        siteRepository: _FakeSiteRepository(_makeSite()),
        ttsService: _FakeTtsService(),
        localizationCubit: _NoopLocalizationCubit(),
        prefs: prefs,
      );
      // Seed the cubit with a loaded site so playAudio's `state.site`
      // guard passes.
      cubit!.emit(SiteDetailState(
        status: SiteDetailStatus.loaded,
        site: _makeSite(),
      ),);
      async.flushMicrotasks();

      // Fire playAudio without awaiting — fakeAsync owns the clock and
      // the pending Futures, so a stray await inside the callback would
      // not complete. Instead we drain microtasks in stages. The flag
      // is written via `unawaited(_prefs.setAudioPreviewedAtLeastOnce(true))`
      // inside playAudio; each flushMicrotasks lets one more frame
      // of microtasks/awaits run.
      cubit!.playAudio('en', isPremium: false);
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 50));
      async.flushMicrotasks();

      // Tear down inside fakeAsync so the cubit's periodic position
      // ticker does not leak past this scope. Without this the
      // pending Timer keeps the test alive and the runner times out.
      cubit!.stopAudio();
      async.flushMicrotasks();
      cubit!.close();
      async.flushMicrotasks();
    });

    // Re-read the singleton to confirm the write landed.
    final fresh = await SharedPrefsService.getInstance();
    expect(
      fresh.audioPreviewedAtLeastOnce,
      isTrue,
      reason:
          'After the first successful playAudio, the SharedPreferences '
          'flag must be set so the post-login gate suppresses the value-prop screen.',
    );
  });
}
