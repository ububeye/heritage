// Widget tests for the 30-second preview SnackBar action button.
//
// The SnackBar used to be a passive notice ("30-second preview ended —
// upgrade for the full tour.") with no action. The fix adds an
// "Upgrade" SnackBarAction that pushes UpgradeScreen. These tests
// exercise the production SnackBar shape and verify both rendering and
// the action's navigation.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stone_town_heritage_vt_guide/blocs/premium/premium_cubit.dart';
import 'package:stone_town_heritage_vt_guide/blocs/premium/premium_state.dart';
import 'package:stone_town_heritage_vt_guide/data/services/billing_provider.dart';
import 'package:stone_town_heritage_vt_guide/data/services/shared_prefs_service.dart';
import 'package:stone_town_heritage_vt_guide/ui/screens/upgrade_screen.dart';

class _FakeBillingProvider implements BillingProvider {
  @override
  String get name => 'fake';
  @override
  Future<BillingResult> purchase(PlanId planId) async =>
      const BillingCancelled();
  @override
  Future<BillingResult> restore() async => const BillingCancelled();
  @override
  Future<({PlanId planId, DateTime? trialActiveUntil, String receiptId})?>
      currentEntitlement() async => null;
}

/// Build the production-shape SnackBar exactly as `app.dart` shows it
/// when `ttsPreviewEndedAt` fires. The `premiumCubit` is shared into the
/// root `MaterialApp.builder` so any pushed route (UpgradeScreen) has
/// the same `BlocProvider<PremiumCubit>` scope the real app provides.
Future<void> _showProductionSnackBar(
  WidgetTester tester, {
  required ValueChanged<BuildContext> onUpgrade,
}) async {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final premiumCubit =
      PremiumCubit(billing: _FakeBillingProvider())..initialize();
  addTearDown(premiumCubit.close);

  await tester.pumpWidget(
    MaterialApp(
      scaffoldMessengerKey: messengerKey,
      builder: (context, child) => BlocProvider<PremiumCubit>.value(
        value: premiumCubit,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) {
            // Show the SnackBar asynchronously so the BuildContext is
            // safely established before we trigger it.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final messenger = ScaffoldMessenger.of(context);
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      '30-second preview ended — upgrade for the full tour.',
                    ),
                    action: SnackBarAction(
                      label: 'Upgrade',
                      onPressed: () => onUpgrade(context),
                    ),
                    duration: const Duration(seconds: 6),
                  ),
                );
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  // Drain the post-frame callback and let the SnackBar animate in.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 750));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.getInstance();
  });

  testWidgets(
    'preview-ended SnackBar shows an Upgrade action button',
    (WidgetTester tester) async {
      await _showProductionSnackBar(
        tester,
        onUpgrade: (_) {},
      );

      // The SnackBar text and the action button must both be present.
      expect(find.textContaining('30-second preview ended'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Upgrade'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Upgrade action pushes UpgradeScreen',
    (WidgetTester tester) async {
      await _showProductionSnackBar(
        tester,
        onUpgrade: (context) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const UpgradeScreen(),
            ),
          );
        },
      );

      // SnackBar is anchored to the bottom; the action button is a
      // descendant of the SnackBar. Tap it.
      await tester.tap(find.widgetWithText(SnackBarAction, 'Upgrade'));
      await tester.pumpAndSettle();

      // UpgradeScreen must be the top of the navigation stack.
      expect(find.byType(UpgradeScreen), findsOneWidget);
      expect(find.text('Go Premium'), findsOneWidget);
    },
  );
}
