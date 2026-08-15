// Unit tests for the `TtsService.previewChunkFor` premium guard.
//
// Background: prior to the fix, `previewChunkFor` always called
// `_chunkForDuration(text, _maxDurationSeconds)`. For premium users,
// `_maxDurationSeconds` is 0, so the chunker computed `maxWords = 0`
// and truncated the text on the very first word — meaning the
// `SiteDetailCubit` handed a *truncated* string to `startReportingPosition`
// while the engine was actually speaking the *full* text. The reporter's
// fingerprint (computed from the truncated string) never matched the
// progress callbacks' text, so every callback was filtered as stale and
// the audio progress bar froze.
//
// The fix adds an early-return for premium: return the full text,
// wasCut=false. These tests pin that behavior and lock down the
// free-tier chunker contract (short text passthrough, long-text
// sentence-boundary truncation).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stone_town_heritage_vt_guide/data/services/runtime_config_service.dart';
import 'package:stone_town_heritage_vt_guide/data/services/tts_service.dart';

// Note: `WidgetsFlutterBinding.ensureInitialized()` is called inside
// `setUpAll` because the `TtsService` field initializer constructs a
// `FlutterTts`, which registers a `MethodChannel` handler. Without the
// binding the platform-channel assertion fires before any test body
// runs.

/// Test double that swaps out `init()` and `dispose()` — both of
/// which would call into the native `FlutterTts` plugin — with no-ops.
/// The chunker is a pure function over the input text, the `_isPremium`
/// flag, and `_maxDurationSeconds`, none of which need the engine to be
/// alive.
class _NoInitTtsService extends TtsService {
  _NoInitTtsService() {
    // Intentionally do NOT call `super.init()` — it would hit native
    // FlutterTts APIs (setSharedInstance, setSpeechRate, etc.) that
    // have no platform implementation in the test environment.
    //
    // We still need `_maxDurationSeconds` populated for the free-tier
    // chunker; setPremium() -> _updateMaxDuration() does that for us,
    // and _updateMaxDuration reads from RuntimeConfigService — hence
    // the setUpAll harness below.
  }

  /// `TtsService.dispose` calls `FlutterTts.stop()`, which has no
  /// plugin implementation in the test environment. The chunker under
  /// test does not own any native resources, so a no-op is correct.
  @override
  void dispose() {}
}

void main() {
  // `setPremium` -> `_updateMaxDuration` reads `freeAudioMaxSeconds`
  // from `RuntimeConfigService`, which in turn reads from
  // SharedPreferences. Mirror the harness established in
  // `routing_service_test.dart` so the chunker sees a known-good
  // 30 s budget.
  //
  // `WidgetsFlutterBinding.ensureInitialized()` is required because
  // the `TtsService` field initializer constructs a `FlutterTts`,
  // which registers a `MethodChannel` handler. Without the binding,
  // the platform-channel assertion fires before any test body runs.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await RuntimeConfigService.getInstance();
  });

  group('TtsService.previewChunkFor', () {
    test(
      'premium user with long text returns the FULL text unchanged, wasCut=false',
      () {
        final service = _NoInitTtsService();
        service.setPremium(true);

        const longText =
            'a long description with multiple sentences that should normally be truncated for free users. another sentence. and another.';

        final chunk = service.previewChunkFor(longText);

        expect(
          chunk.text,
          longText,
          reason:
              'Premium users must receive the full input verbatim — '
              'the chunker must not run when _isPremium is true.',
        );
        expect(
          chunk.wasCut,
          isFalse,
          reason:
              'Premium preview is never a cut; wasCut=false is what the '
              'cubit uses to decide whether to show the upgrade prompt.',
        );

        service.dispose();
      },
    );

    test('free user with short text returns the text as-is, wasCut=false', () {
      final service = _NoInitTtsService();
      service.setPremium(false);

      const shortText = 'short text';

      final chunk = service.previewChunkFor(shortText);

      expect(chunk.text, shortText);
      expect(chunk.wasCut, isFalse);

      service.dispose();
    });

    test(
      'free user with long text beyond the 30s budget truncates at a sentence boundary, wasCut=true',
      () {
        final service = _NoInitTtsService();
        service.setPremium(false);

        // 30 s * 2.5 words/sec = 75 word budget. This passage is well
        // past that — ~140 words — so the chunker must cut. We expect
        // the cut to land at a sentence terminator (., !, ?), so the
        // truncated output should end with `.` (after trimRight).
        const longText =
            'Forodhani Gardens is a waterfront park in Stone Town that comes alive every evening with food vendors grilling seafood and Zanzibari street food. '
            'Families gather along the seawall to watch the dhows return from the afternoon fishing trips and to share meals as the sun sets behind the harbor. '
            'The night market offers sugar cane juice, spiced tea, urojo soup, and freshly caught octopus skewers served with tamarind sauce. '
            'Tourists and locals mingle at communal benches while vendors call out the day\'s specials in Swahili and English. '
            'It is widely considered the most atmospheric evening experience in Zanzibar and a must-visit for first-time travelers. '
            'The garden is named after the original fortification that once guarded this stretch of coastline. '
            'Today the site functions as both a public park and a living cultural crossroads where the old town meets the sea.';

        final chunk = service.previewChunkFor(longText);

        expect(
          chunk.text.length,
          lessThan(longText.length),
          reason: 'Free tier must truncate text that exceeds the budget.',
        );
        expect(
          chunk.wasCut,
          isTrue,
          reason: 'Truncated output must flag wasCut so the UI prompts upgrade.',
        );
        // Sentence-boundary truncation — the cut must end with a
        // terminator (after trimRight). The chunker strips trailing
        // whitespace before returning, so a regex on the trimmed end
        // is the right check.
        expect(
          RegExp(r'[.!?]$').hasMatch(chunk.text),
          isTrue,
          reason:
              'Chopped output must end at a sentence terminator, not mid-word. '
              'Got: "${chunk.text.substring(chunk.text.length - 20)}"',
        );
        // And the truncation must not have leaked the budget-fallback
        // cue string — that branch only fires when there is no
        // terminator at all in the entire input.
        expect(
          chunk.text.contains('Upgrade to hear the full tour'),
          isFalse,
          reason:
              'A long passage with multiple terminators must not hit '
              'the no-terminator fallback path.',
        );

        service.dispose();
      },
    );

    test('premium user with empty text returns empty, wasCut=false', () {
      final service = _NoInitTtsService();
      service.setPremium(true);

      final chunk = service.previewChunkFor('');

      expect(chunk.text, '');
      expect(chunk.wasCut, isFalse);

      service.dispose();
    });

    test(
      'premium user with single-sentence text returns the text unchanged, wasCut=false',
      () {
        final service = _NoInitTtsService();
        service.setPremium(true);

        const oneSentence = 'just one sentence.';

        final chunk = service.previewChunkFor(oneSentence);

        expect(chunk.text, oneSentence);
        expect(chunk.wasCut, isFalse);

        service.dispose();
      },
    );
  });

  group('TtsService.previewChunkFor regression guard', () {
    test(
      'premium path does NOT delegate to _chunkForDuration — would yield truncated text otherwise',
      () {
        // Regression: before the fix, the premium path ran the chunker
        // with `_maxDurationSeconds = 0`, which produced `maxWords = 0`
        // and cut on the first word. That truncated string is what the
        // cubit was fingerprinting progress callbacks against, while
        // the engine was speaking the full text — every callback was
        // then filtered as stale and the progress bar froze. This test
        // confirms the early-return path bypasses the chunker entirely.
        final service = _NoInitTtsService();
        service.setPremium(true);

        // A string whose first word is "Stone" — if the bug regressed,
        // the chunker would return something like "Stone. Upgrade to
        // hear the full tour." because maxWords=0 forces the
        // no-terminator fallback.
        const fullText = 'Stone Town is a UNESCO World Heritage Site.';

        final chunk = service.previewChunkFor(fullText);

        expect(
          chunk.text,
          fullText,
          reason:
              'Premium users must NEVER see the chunker-fallback cue '
              '("Upgrade to hear the full tour") appended to their preview.',
        );
        expect(chunk.text.contains('Upgrade to hear the full tour'), isFalse);

        service.dispose();
      },
    );
  });
}
