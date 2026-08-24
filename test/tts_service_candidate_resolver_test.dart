// Pure-function tests for TtsService.resolveBestCandidate.
//
// The helper lives at the top of `tts_service.dart` (next to the
// `_voiceCandidates` table) so we can import it directly without
// instantiating TtsService. No flutter_tts mock is needed — every test
// just exercises the resolver logic against synthetic BCP-47 lists.

import 'package:flutter_test/flutter_test.dart';
import 'package:stone_town_heritage_vt_guide/data/services/tts_service.dart';

void main() {
  group('resolveBestCandidate', () {
    test('exact match wins against other locales', () {
      expect(
        resolveBestCandidate('en', ['en-US', 'fr-FR', 'de-DE']),
        'en-US',
      );
    });

    test('falls back to a less-preferred candidate in the same family', () {
      // Device has fr-CA but not fr-FR — should still resolve French.
      expect(
        resolveBestCandidate('fr', ['en-US', 'fr-CA', 'de-DE']),
        'fr-CA',
      );
    });

    test('returns the second preferred when the first is missing', () {
      // No en-US in the available list — should fall through to en-GB.
      expect(
        resolveBestCandidate('en', ['en-GB', 'fr-FR']),
        'en-GB',
      );
    });

    test('returns null when no family member is installed', () {
      expect(resolveBestCandidate('fr', ['en-US', 'de-DE']), isNull);
    });

    test('falls back to prefix wildcard for engine-extended tags', () {
      // Some OEMs ship `fr-XX-zzz` or `fr-FR-android-tts`. The resolver
      // should catch these via startsWith('fr-') even when the tag
      // isn't in the candidate table.
      expect(
        resolveBestCandidate('fr', ['en-US', 'fr-XX-zzz']),
        'fr-XX-zzz',
      );
    });

    test('returns null for an unsupported short code', () {
      expect(resolveBestCandidate('zh', ['en-US', 'zh-CN']), isNull);
    });

    test('returns null for an empty available list', () {
      expect(resolveBestCandidate('en', const []), isNull);
    });
  });

  group('resolveShortCodesForAvailable', () {
    test('lists every short code the device can speak', () {
      // Device with en-US, fr-CA, de-DE installed.
      final codes = resolveShortCodesForAvailable([
        'en-US',
        'fr-CA',
        'de-DE',
      ]);
      expect(codes, containsAll(['en', 'fr', 'de']));
      expect(codes, isNot(contains('sw')));
      expect(codes, isNot(contains('ar')));
    });

    test('returns an empty list when nothing matches', () {
      expect(resolveShortCodesForAvailable(['xx-YY', 'zz-AA']), isEmpty);
    });

    test('catches engine-extended tags via prefix wildcard', () {
      final codes = resolveShortCodesForAvailable(['en-US', 'fr-XX-zzz']);
      expect(codes, containsAll(['en', 'fr']));
    });
  });
}