import 'package:flutter/foundation.dart';

/// Which subscription plan the user picked on the upgrade screen. Maps
/// 1:1 to the productIds in the store console:
///   `monthly`  →  `stone_town_premium_monthly`
///   `yearly`   →  `stone_town_premium_yearly`  (default selection)
enum PlanId { monthly, yearly }

/// Outcome of the last purchase / restore flow. Latched on the cubit so
/// the UI can paint a banner / dialog without re-deriving from raw
/// BillingResult objects every build.
enum PurchaseOutcome { idle, success, cancelled, pending, error }

@immutable
class PremiumState {
  const PremiumState({
    this.selectedPlanId = PlanId.yearly,
    this.isPremium = false,
    this.isLoading = false,
    this.showPremiumOffer = true,
    this.lastOutcome = PurchaseOutcome.idle,
    this.errorMessage,
    this.trialActiveUntil,
    this.lastReceiptId,
  });

  /// Default selection on screen open. Yearly is the recommended path.
  final PlanId selectedPlanId;

  /// True when the user has an active entitlement. Source-of-truth-check
  /// is the BillingProvider; this field is the UI cache.
  final bool isPremium;

  /// True while a purchase / restore / initialize is in flight. Disables
  /// the primary CTA and shows the spinner.
  final bool isLoading;

  /// First-launch paywall. Set to `false` after the user subscribes,
  /// taps "Maybe later", or finishes onboarding.
  final bool showPremiumOffer;

  /// Latched result of the last purchase / restore. Resets to `idle`
  /// when the screen receives a new intent.
  final PurchaseOutcome lastOutcome;

  /// Set when lastOutcome == error.
  final String? errorMessage;

  /// When the trial converts. Null when the user paid up-front.
  final DateTime? trialActiveUntil;

  /// Synthetic / real receipt id of the last successful purchase. Kept
  /// for diagnostics and for the success dialog.
  final String? lastReceiptId;

  bool get hasError =>
      lastOutcome == PurchaseOutcome.error && errorMessage != null;

  PremiumState copyWith({
    PlanId? selectedPlanId,
    bool? isPremium,
    bool? isLoading,
    bool? showPremiumOffer,
    PurchaseOutcome? lastOutcome,
    String? errorMessage,
    DateTime? trialActiveUntil,
    String? lastReceiptId,
  }) {
    return PremiumState(
      selectedPlanId: selectedPlanId ?? this.selectedPlanId,
      isPremium: isPremium ?? this.isPremium,
      isLoading: isLoading ?? this.isLoading,
      showPremiumOffer: showPremiumOffer ?? this.showPremiumOffer,
      lastOutcome: lastOutcome ?? this.lastOutcome,
      errorMessage: errorMessage,
      trialActiveUntil: trialActiveUntil ?? this.trialActiveUntil,
      lastReceiptId: lastReceiptId ?? this.lastReceiptId,
    );
  }
}
