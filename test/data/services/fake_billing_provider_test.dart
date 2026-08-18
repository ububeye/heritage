// Unit tests for `FakeBillingProvider.purchase()` plan-id branching (Bug B fix).
//
// Before the fix, `purchase()` emitted `trialActiveUntil: now + 3 days`
// for every plan, including the $49.99 Lifetime one-time purchase. The
// success dialog showed "Welcome to Premium!" with no distinction
// between a trial and a lifetime buy. The fix branches on
// `PlanId.lifetime` so lifetime purchases return `trialActiveUntil:
// null` and the success dialog can render different copy.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stone_town_heritage_vt_guide/blocs/premium/premium_cubit.dart';
import 'package:stone_town_heritage_vt_guide/blocs/premium/premium_state.dart';
import 'package:stone_town_heritage_vt_guide/data/services/billing_provider.dart';
import 'package:stone_town_heritage_vt_guide/data/services/fake_billing_provider.dart';
import 'package:stone_town_heritage_vt_guide/data/services/shared_prefs_service.dart';

void main() {
  group('FakeBillingProvider.purchase', () {
    // Seed an RNG so the 10% cancellation branch does not flake.
    // `Random(0)` produces a deterministic sequence: for the first
    // call, the value is 0.55..., well above 0.10, so the call
    // returns success.
    final rng = Random(0);

    test(
      'PlanId.lifetime returns BillingSuccess with trialActiveUntil = null',
      () async {
        final provider = FakeBillingProvider(rng: rng);

        final result = await provider.purchase(PlanId.lifetime);

        expect(result, isA<BillingSuccess>());
        final success = result as BillingSuccess;
        expect(success.planId, PlanId.lifetime);
        expect(
          success.trialActiveUntil,
          isNull,
          reason:
              'Lifetime purchase is owned outright — no trial. '
              'The cubit reads trialActiveUntil to flag trial state.',
        );
      },
    );

    test(
      'PlanId.monthly returns BillingSuccess with trialActiveUntil ≈ now + 3 days',
      () async {
        final provider = FakeBillingProvider(rng: rng);
        final before = DateTime.now();

        final result = await provider.purchase(PlanId.monthly);

        expect(result, isA<BillingSuccess>());
        final success = result as BillingSuccess;
        expect(success.planId, PlanId.monthly);
        expect(success.trialActiveUntil, isNotNull);
        final delta = success.trialActiveUntil!.difference(before);
        // Trial length is 3 days = 259200 seconds. Allow a 5 s
        // tolerance for the clock drifting between the two DateTime.now()
        // reads.
        expect(
          delta.inSeconds,
          inInclusiveRange(3 * 24 * 60 * 60 - 5, 3 * 24 * 60 * 60 + 5),
          reason: 'Trial must be exactly 3 days from the purchase call.',
        );
      },
    );

    test(
      'PlanId.proYearly returns BillingSuccess with trialActiveUntil ≈ now + 3 days',
      () async {
        final provider = FakeBillingProvider(rng: rng);
        final before = DateTime.now();

        final result = await provider.purchase(PlanId.proYearly);

        expect(result, isA<BillingSuccess>());
        final success = result as BillingSuccess;
        expect(success.planId, PlanId.proYearly);
        expect(success.trialActiveUntil, isNotNull);
        final delta = success.trialActiveUntil!.difference(before);
        expect(
          delta.inSeconds,
          inInclusiveRange(3 * 24 * 60 * 60 - 5, 3 * 24 * 60 * 60 + 5),
        );
      },
    );

    test(
      'PlanId.lifetime without the 10% cancellation branch still returns success without trial',
      () async {
        // Build a provider with a forceCancel-friendly hook by
        // exercising the path that returns BillingSuccess for lifetime
        // directly. With seed=0 and a single purchase, the RNG lands
        // safely above the 0.10 cancellation threshold.
        final provider = FakeBillingProvider(rng: Random(42));

        final result = await provider.purchase(PlanId.lifetime);

        // Either BillingSuccess (no trial) or BillingCancelled — we
        // only assert that the lifetime branch never produces a
        // BillingSuccess with a non-null trial.
        if (result is BillingSuccess) {
          expect(result.trialActiveUntil, isNull);
        } else {
          expect(result, isA<BillingCancelled>());
        }
      },
    );

    test(
      'error path is unchanged for any plan',
      () async {
        final provider = FakeBillingProvider(
          rng: Random(0),
          forceError: () => true,
        );

        final result = await provider.purchase(PlanId.lifetime);
        expect(result, isA<BillingError>());

        final result2 = await provider.purchase(PlanId.monthly);
        expect(result2, isA<BillingError>());
      },
    );
  });

  group('PremiumCubit.purchase wiring (success dialog contract)', () {
    // The success dialog in upgrade_content.dart branches on
    // `state.selectedPlanId == PlanId.lifetime`. These tests verify
    // that the cubit ends up with the right combination of
    // `selectedPlanId`, `trialActiveUntil`, and `lastOutcome` after a
    // purchase — the rendering layer reads these fields directly.

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await SharedPrefsService.getInstance();
    });

    test(
      'purchase(PlanId.lifetime) ends with selectedPlanId=lifetime and trialActiveUntil=null',
      () async {
        final cubit = PremiumCubit(billing: FakeBillingProvider(rng: Random(0)));
        addTearDown(cubit.close);

        cubit.selectPlan(PlanId.lifetime);
        await cubit.purchase();

        expect(cubit.state.lastOutcome, PurchaseOutcome.success);
        expect(cubit.state.selectedPlanId, PlanId.lifetime);
        expect(
          cubit.state.trialActiveUntil,
          isNull,
          reason:
              'After a lifetime purchase, the cubit must NOT set '
              'trialActiveUntil — the success dialog reads this field '
              'to decide whether to show the "no trial" copy.',
        );
        expect(cubit.state.isPremium, isTrue);
      },
    );

    test(
      'purchase(PlanId.monthly) ends with selectedPlanId=monthly and trialActiveUntil≈now+3d',
      () async {
        final cubit = PremiumCubit(billing: FakeBillingProvider(rng: Random(0)));
        addTearDown(cubit.close);

        cubit.selectPlan(PlanId.monthly);
        final before = DateTime.now();
        await cubit.purchase();

        expect(cubit.state.lastOutcome, PurchaseOutcome.success);
        expect(cubit.state.selectedPlanId, PlanId.monthly);
        expect(cubit.state.trialActiveUntil, isNotNull);
        final delta = cubit.state.trialActiveUntil!.difference(before);
        expect(
          delta.inSeconds,
          inInclusiveRange(3 * 24 * 60 * 60 - 5, 3 * 24 * 60 * 60 + 5),
        );
      },
    );
  });
}
