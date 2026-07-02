import 'package:flutter/foundation.dart';
import '../../blocs/premium/premium_state.dart';

/// Result of a billing operation. Sealed so consumers must handle every
/// variant — the cubit never silently swallows success / cancelled /
/// pending / error.
@immutable
sealed class BillingResult {
  const BillingResult();
}

class BillingSuccess extends BillingResult {
  const BillingSuccess({
    required this.planId,
    required this.receiptId,
    this.trialActiveUntil,
  });
  final PlanId planId;

  /// Synthetic server-side receipt id. The real provider replaces this
  /// with a Play Store / RevenueCat receipt token.
  final String receiptId;

  /// Null when the user paid in full, non-null for trial conversions.
  final DateTime? trialActiveUntil;
}

class BillingCancelled extends BillingResult {
  const BillingCancelled();
}

class BillingPending extends BillingResult {
  const BillingPending();
}

class BillingError extends BillingResult {
  const BillingError(this.message, {this.retryable = true});
  final String message;
  final bool retryable;
}

/// Abstraction over the underlying store / SDK. The shipped app uses a
/// fake for the UI to bind to; a real implementation (RevenueCat, Google
/// Play Billing) lands behind this interface.
abstract class BillingProvider {
  /// Identifier of the implementation — surfaced for diagnostics.
  String get name;

  /// Begin a purchase flow for [planId]. Must not throw; surface errors
  /// as [BillingError].
  Future<BillingResult> purchase(PlanId planId);

  /// Restore previously purchased entitlements for the current account.
  /// Returns [BillingSuccess] with `planId: PlanId.yearly` and a synthetic
  /// receipt when an entitlement exists; [BillingCancelled] when there's
  /// nothing to restore (matches the Play Billing contract).
  Future<BillingResult> restore();

  /// Ask the provider for the authoritative entitlement of the current
  /// account. The cubit calls this on `initialize`. Returns `null` when
  /// the user has never bought anything.
  Future<({PlanId planId, DateTime? trialActiveUntil, String receiptId})?>
      currentEntitlement();
}
