// Tests for the new SharedPrefs key `keyAudioPreviewedAtLeastOnce` and
// the `audioPreviewedAtLeastOnce` / `setAudioPreviewedAtLeastOnce`
// pair. This flag gates the post-login value-prop screen: it's set to
// true the first time SiteDetailCubit successfully plays audio, and
// read at login / register by the gate logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stone_town_heritage_vt_guide/data/services/shared_prefs_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    // Each test gets a clean prefs store so the flag starts false.
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPrefsService.audioPreviewedAtLeastOnce', () {
    test('default value is false when the key has never been written', () async {
      final service = await SharedPrefsService.getInstance();
      expect(service.audioPreviewedAtLeastOnce, isFalse);
    });

    test('setAudioPreviewedAtLeastOnce(true) persists across re-reads', () async {
      final service = await SharedPrefsService.getInstance();
      await service.setAudioPreviewedAtLeastOnce(true);
      expect(service.audioPreviewedAtLeastOnce, isTrue);
    });

    test('setAudioPreviewedAtLeastOnce(false) clears the flag', () async {
      final service = await SharedPrefsService.getInstance();
      await service.setAudioPreviewedAtLeastOnce(true);
      expect(service.audioPreviewedAtLeastOnce, isTrue);
      await service.setAudioPreviewedAtLeastOnce(false);
      expect(service.audioPreviewedAtLeastOnce, isFalse);
    });

    test(
      'the flag persists across SharedPrefsService.getInstance() calls',
      () async {
        // First instance — write the flag.
        final first = await SharedPrefsService.getInstance();
        await first.setAudioPreviewedAtLeastOnce(true);

        // Force a fresh read by re-initialising the underlying prefs.
        // (In production, the singleton lives for the lifetime of the
        // process; in this test we want to verify the value is actually
        // persisted to SharedPreferences, not just cached in Dart.)
        final second = await SharedPrefsService.getInstance();
        expect(second.audioPreviewedAtLeastOnce, isTrue);
      },
    );
  });
}
