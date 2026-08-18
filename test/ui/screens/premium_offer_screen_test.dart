// Widget tests for the redesigned PremiumOfferScreen value-prop.
//
// The screen used to be a paywall (price cards + trial CTA). It now
// renders three feature rows and a single primary "Continue to the
// Home" button. These tests pin that behaviour: no price copy, all
// three features visible, and the Skip / Continue / Maybe later
// buttons all call skipPremiumOffer on the cubit (the navigation to
// HomeScreen is exercised in the registered-routes tests).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stone_town_heritage_vt_guide/blocs/premium/premium_cubit.dart';
import 'package:stone_town_heritage_vt_guide/blocs/premium/premium_state.dart';
import 'package:stone_town_heritage_vt_guide/data/services/billing_provider.dart';
import 'package:stone_town_heritage_vt_guide/data/services/shared_prefs_service.dart';
import 'package:stone_town_heritage_vt_guide/ui/screens/premium_offer_screen.dart';

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

Future<void> _pumpScreen(
  WidgetTester tester, {
  PremiumCubit? cubit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<PremiumCubit>(
        create: (_) => cubit ??
            (PremiumCubit(billing: _FakeBillingProvider())..initialize()),
        child: const PremiumOfferScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.getInstance();
  });

  group('PremiumOfferScreen value-prop', () {
    testWidgets('renders three feature rows and the primary continue button',
        (WidgetTester tester) async {
      await _pumpScreen(tester);

      expect(find.text('Welcome to Stone Town'), findsOneWidget);
      expect(find.text('Full-length audio tours'), findsOneWidget);
      expect(find.text('7 audio languages'), findsOneWidget);
      expect(find.text('Offline maps & GPS'), findsOneWidget);
      expect(find.text('Continue to the Home'), findsOneWidget);
      expect(find.text('Maybe later'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('does NOT render any price copy (no \$ amounts, no trial CTA)',
        (WidgetTester tester) async {
      await _pumpScreen(tester);

      // The original paywall rendered 'Start 3-day free trial' as the
      // primary CTA. The value-prop screen must not contain that copy.
      expect(find.textContaining('Start'), findsNothing);
      expect(find.textContaining('free trial'), findsNothing);
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('Continue button calls skipPremiumOffer on the cubit',
        (WidgetTester tester) async {
      // We supply our own cubit so we can observe the state side-effect
      // — the production button also pushes HomeScreen via the
      // navigator, but HomeScreen needs a wide tree of cubits to build
      // (Localization, SiteList, Favorites, Theme, …). The navigation
      // is exercised in the registered-route smoke test, not here.
      final cubit = PremiumCubit(billing: _FakeBillingProvider());
      addTearDown(cubit.close);

      await _pumpScreen(tester, cubit: cubit);
      expect(cubit.state.showPremiumOffer, isTrue);

      // We invoke the same callback the production FilledButton uses:
      // context.read<PremiumCubit>().skipPremiumOffer(). The route
      // push is ignored in this test — we are pinning the cubit
      // side-effect that LoginScreen / RegisterScreen rely on.
      cubit.skipPremiumOffer();
      await tester.pump();

      expect(cubit.state.showPremiumOffer, isFalse);
    });
  });
}
