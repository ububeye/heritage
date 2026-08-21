import 'dart:async';
import 'dart:math';

import '../../blocs/premium/premium_state.dart';
import 'billing_provider.dart';

/// In-app-only billing implementation used while real store credentials
/// are not configured. Behaves like a real SDK:
///   - Adds a realistic 800–1200 ms latency to the network call.
///   - Emits [BillingCancelled] ~10 % of the time (representing the user
///     tapping back in the Play sheet).
///   - Emits [BillingError] when [forceError] returns true, or when
///     [simulatedNetworkDown] is true.
///   - Otherwise returns [BillingSuccess] with a synthetic receipt.
///
/// Trials are simulated — every purchase sets `trialActiveUntil` to
/// `now + AppConstants.trialDays`, which the cubit renders as the
/// "Your trial is active" copy until expiry.
class FakeBillingProvider implements BillingProvider {
  FakeBillingProvider({
    this.forceError,
    this.simulatedNetworkDown = false,
    this.seedRandomCancellation = true,
    Random? rng,
  }) : _rng = rng ?? Random();

  /// Provide a closure returning `true` to deterministically force a
  /// [BillingError] (useful for widget tests).
  final bool Function()? forceError;

  /// When true, every purchase / restore returns a transient
  /// `Network unavailable` error after a short delay.
  final bool simulatedNetworkDown;

  /// When true (default), ~10% of purchases round to [BillingCancelled]
  /// so the cancelled branch of the UI is reachable in manual QA and
  /// integration tests. Pass `false` from `app.dart` for shipped demo
  /// builds — the demo user expects every successful tap to unlock
  /// premium, not have a 1-in-10 chance of silently dismissing. Tests
  /// that need the cancelled branch can still flip this flag on (or
  /// use [forceCancel] for a deterministic single-call cancel).
  final bool seedRandomCancellation;

  /// RNG used to introduce latency + occasional cancellation. Pass a
  /// seeded `Random(0)` in tests for deterministic behaviour.
  final Random _rng;

  /// Whether the most recent purchase flow should report cancelled.
  /// Flipped via [forceCancel] for tests.
  bool forceCancel = false;

  /// When non-null, the next [restore] call returns this entitlement.
  /// Lets tests assert the "already a member" flow without going through
  /// purchase first.
  ({PlanId planId, DateTime? trialActiveUntil, String receiptId})? restoreStash;

  @override
  String get name => 'fake';

  @override
  Future<BillingResult> purchase(PlanId planId) async {
    await _simulateLatency();

    if (simulatedNetworkDown) {
      return const BillingError(
        'Network unavailable. Check your connection and try again.',
      );
    }
    if (forceError?.call() ?? false) {
      return const BillingError('Purchase failed (simulated).');
    }
    if (forceCancel) {
      forceCancel = false;
      return const BillingCancelled();
    }

    // Round 10 % of purchases to cancelled so the cancelled branch of the
    // UI is reachable in manual QA. Gated on [seedRandomCancellation] so
    // shipped demo builds (see `app.dart`) can opt out and always return
    // success — the user shouldn't see a fake random cancel when they
    // haven't actually cancelled anything.
    if (seedRandomCancellation && _rng.nextDouble() < 0.10) {
      return const BillingCancelled();
    }

    final receipt = 'fake-${DateTime.now().millisecondsSinceEpoch}';
    // Lifetime is a one-time purchase — no trial. Other plans
    // (monthly, yearly, proMonthly, proYearly) start with a 3-day
    // trial to mirror the real RevenueCat/Play Store semantics.
    final isLifetime = planId == PlanId.lifetime;
    final trialEnd =
        isLifetime ? null : DateTime.now().add(const Duration(days: 3));
    return BillingSuccess(
      planId: planId,
      receiptId: receipt,
      trialActiveUntil: trialEnd,
    );
  }

  @override
  Future<BillingResult> restore() async {
    await _simulateLatency();

    if (simulatedNetworkDown) {
      return const BillingError(
        'Network unavailable. Check your connection and try again.',
      );
    }
    if (forceError?.call() ?? false) {
      return const BillingError('Restore failed (simulated).');
    }

    final stash = restoreStash;
    if (stash == null) {
      // No entitlement — match real SDK behaviour: cancelled, not error.
      return const BillingCancelled();
    }
    return BillingSuccess(
      planId: stash.planId,
      receiptId: stash.receiptId,
      trialActiveUntil: stash.trialActiveUntil,
    );
  }

  @override
  Future<({PlanId planId, DateTime? trialActiveUntil, String receiptId})?>
  currentEntitlement() async {
    await _simulateLatency();
    return restoreStash;
  }

  Future<void> _simulateLatency() {
    final ms = 800 + _rng.nextInt(400);
    return Future<void>.delayed(Duration(milliseconds: ms));
  }
}
