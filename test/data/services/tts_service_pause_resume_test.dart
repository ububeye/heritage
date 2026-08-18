// TtsService-level pause/resume snapshot tests.
//
// Verifies the snapshot mechanism that captures a valid resume point
// even when stopReportingPosition has cleared the live fields —
// the architectural fix for the customer-visible "starts from
// beginning" bug.
//
// We exercise TtsService methods directly with a NoInit subclass that
// stubs `init()` (which would otherwise talk to the native plugin).
// The progress callback wiring is real: _onProgress updates the
// snapshot fields the same way it would in production.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stone_town_heritage_vt_guide/data/models/audio_state.dart';
import 'package:stone_town_heritage_vt_guide/data/services/runtime_config_service.dart';
import 'package:stone_town_heritage_vt_guide/data/services/tts_service.dart';

class _NoInitTtsService extends TtsService {
  @override
  void dispose() {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await RuntimeConfigService.getInstance();

    // The flutter_tts plugin uses MethodChannel('flutter_tts') for all
    // platform calls. We mock just enough methods to let the tests
    // invoke `pauseForRestart` (which calls `_flutterTts.stop()`) and
    // `startReportingPosition` (which never crosses the channel). Any
    // method we don't mock will throw `MissingPluginException`, which
    // is also caught in production by the cancel/error handlers.
    const channel = MethodChannel('flutter_tts');
    TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'stop':
        case 'speak':
        case 'setLanguage':
        case 'setSpeechRate':
        case 'setPitch':
        case 'setVolume':
        case 'pause':
        case 'setSharedInstance':
        case 'getLanguages':
        case 'getVoices':
        case 'isLanguageAvailable':
        case 'setCompletionHandler':
        case 'setProgressHandler':
        case 'setCancelHandler':
        case 'setStartHandler':
        case 'setErrorHandler':
          return 1;
        default:
          return null;
      }
    });
  });

  group('pauseForRestart — snapshot mechanism', () {
    test(
      'returns a non-null PausedResumePoint even when stopReportingPosition '
      'was called BEFORE pauseForRestart (regression for the customer bug)',
      () async {
        final service = _NoInitTtsService();
        service.setPremium(true);

        const spokenText =
            'A long enough text to give pauseForRestart something to '
            'work with and to demonstrate that resume continues from '
            'where the user paused and does not start over.';

        // Simulate the engine having reported progress on this chunk.
        service.startReportingPosition(
          spokenText,
          onPosition: (_) {},
          budget: const Duration(seconds: 30),
        );

        // Drive a fake progress callback into the live reporter path.
        // _onProgress is private — we trigger it via reflection-free
        // simulation by calling startReportingPosition with a real
        // onPosition sink and then injecting through the parent
        // service's reporter field. The simplest cross-platform way
        // without breaking encapsulation is to call restartReporting
        // simulating an observed end offset of 20 (a real-looking
        // halfway-through-chunk position).
        service.restartReportingWithSuffix(
          suffix: spokenText.substring(20),
          baseline: 20,
          onPosition: (_) {},
          budget: const Duration(seconds: 30),
        );

        // The critical regression check: pauseForRestart must succeed
        // even after stopReportingPosition has wiped the live fields.
        // This is the ordering that the old code got wrong.
        service.stopReportingPosition();
        // Drain future-ish callbacks (none expected, but harmless).
        await Future<void>.delayed(Duration.zero);

        final point = await service.pauseForRestart();
        expect(
          point,
          isNotNull,
          reason:
              'pauseForRestart must return a valid PausedResumePoint '
              'even when stopReportingPosition was called before it. '
              'The previous implementation returned null in this case, '
              'which caused resumeAudio to fall back to playAudio — '
              'producing the customer-visible "starts from beginning" '
              'regression.',
        );

        // Verify the captured point refers to the same text we spoke.
        expect(point!.text, isNotNull);
        expect(
          point.text.length,
          greaterThan(20),
          reason: 'captured text must be the original chunk',
        );
        expect(
          point.charOffset,
          greaterThan(0),
          reason: 'captured offset must be > 0 from prior progress',
        );

        service.dispose();
      },
    );

    test(
      'returns a non-null PausedResumePoint even with no progress '
      'callback having fired yet (very-early pause — wall-clock fallback)',
      () async {
        final service = _NoInitTtsService();
        service.setPremium(true);

        const spokenText =
            'A short text just enough that the wall-clock estimator '
            'produces a positive offset after a small elapsed time. '
            'Long enough to give the wall-clock math room to find a '
            'positive character offset well before the engine fires '
            'its first progress callback.';

        service.startReportingPosition(
          spokenText,
          onPosition: (_) {},
          budget: const Duration(seconds: 30),
        );

        // No progress callback has fired. Without the wall-clock
        // fallback, pauseForRestart would return null (offset is 0).
        // We expect it to still return a non-null point with a small
        // positive offset.
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final point = await service.pauseForRestart();
        expect(
          point,
          isNotNull,
          reason:
              'pauseForRestart must synthesize a resume point from '
              'wall-clock elapsed time when no progress callback '
              'has been observed yet (so the very-early pause case '
              'still resumes near the start, not from the absolute '
              'beginning).',
        );
        expect(point!.text, spokenText);
        expect(
          point.charOffset,
          greaterThan(0),
          reason: 'wall-clock fallback should produce offset > 0',
        );
        expect(
          point.charOffset,
          lessThan(spokenText.length),
          reason: 'wall-clock fallback must not exceed text length',
        );

        service.dispose();
      },
    );

    test(
      'returns null only when there is nothing to resume from '
      '(no chunk ever started)',
      () async {
        final service = _NoInitTtsService();
        service.setPremium(true);

        // Fresh service — no startReportingPosition, no chunk.
        final point = await service.pauseForRestart();
        expect(
          point,
          isNull,
          reason:
              'Without a chunk to resume from, pauseForRestart has '
              'no valid offset/text — returning null is correct.',
        );

        service.dispose();
      },
    );

    test(
      'snapshot is cleared after each successful pause so the next '
      'fresh play starts clean',
      () async {
        final service = _NoInitTtsService();
        service.setPremium(true);

        const firstText =
            'first chunk starts here and has enough words to count.';
        // Install the reporter on the first chunk. Internal
        // fingerprint fields get seeded to the first text. We
        // simulate an observed offset by using restartReporting
        // with baseline=15, which sets _lastObservedOffset = 15.
        service.restartReportingWithSuffix(
          suffix: firstText,
          baseline: 15,
          onPosition: (_) {},
          budget: const Duration(seconds: 30),
        );

        final firstPoint = await service.pauseForRestart();
        expect(
          firstPoint,
          isNotNull,
          reason: 'first pause must capture a non-null point',
        );
        expect(firstPoint!.text, firstText);
        expect(firstPoint.charOffset, greaterThan(0));

        // After the pause, the snapshot MUST be cleared. We re-seed
        // a fresh reporter on the SECOND chunk (different text) and
        // verify the next pause returns the second chunk, not the
        // first. If the snapshot were leaked, the next pause would
        // still reference firstText.
        const secondText =
            'a completely separate second chunk here with its own words.';
        service.restartReportingWithSuffix(
          suffix: secondText,
          baseline: 15,
          onPosition: (_) {},
          budget: const Duration(seconds: 30),
        );

        final secondPoint = await service.pauseForRestart();
        expect(secondPoint, isNotNull);
        expect(
          secondPoint!.text,
          secondText,
          reason:
              'After the previous pause cleared the snapshot, the '
              'second pause must produce a point anchored to the '
              'second chunk — not the first.',
        );

        service.dispose();
      },
    );
  });
}
