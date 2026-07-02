import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/billing_provider.dart';
import '../../data/services/shared_prefs_service.dart';
import '../auth/auth_cubit.dart';
import 'premium_state.dart';

/// Owns the upgrade-screen state machine and delegates all store calls to
/// the injected [BillingProvider]. The cubit is the single source of
/// truth for `isPremium` / `selectedPlanId` / `lastOutcome` between
/// screens.
class PremiumCubit extends Cubit<PremiumState> {
  PremiumCubit({
    required BillingProvider billing,
    AuthCubit? auth,
    SharedPrefsService? prefs,
  })  : _billing = billing,
        _auth = auth,
        _prefs = prefs ?? SharedPrefsService.instance,
        super(const PremiumState()) {
    _hydrateFromPrefs();
  }

  final BillingProvider _billing;
  final AuthCubit? _auth;
  final SharedPrefsService _prefs;

  /// Pull cached values from SharedPreferences so the screen paints with
  /// the right state on first frame. The BillingProvider call happens
  /// separately via [initialize].
  void _hydrateFromPrefs() {
    emit(state.copyWith(
      showPremiumOffer: _prefs.showPremiumOffer,
      isPremium: _prefs.isPremiumDemo,
    ),);
  }

  /// App-start hook. Asks the billing provider for the authoritative
  /// entitlement. Resilient to the provider being slow: we don't block
  /// the splash screen, the cubit re-emits when the answer arrives.
  Future<void> initialize() async {
    emit(state.copyWith(
      isLoading: true,
      lastOutcome: PurchaseOutcome.idle,
    ),);
    try {
      final entitlement = await _billing.currentEntitlement();
      if (entitlement != null) {
        emit(state.copyWith(
          isLoading: false,
          isPremium: true,
          selectedPlanId: entitlement.planId,
          trialActiveUntil: entitlement.trialActiveUntil,
          lastReceiptId: entitlement.receiptId,
          lastOutcome: PurchaseOutcome.success,
        ),);
      } else {
        emit(state.copyWith(isLoading: false),);
      }
    } catch (e) {
      // Non-fatal: leave premium=cache and let the user retry from the
      // upgrade screen.
      emit(state.copyWith(isLoading: false),);
    }
  }

  /// Plan card tap.
  void selectPlan(PlanId id) {
    if (state.selectedPlanId == id) return;
    emit(state.copyWith(
      selectedPlanId: id,
      lastOutcome: PurchaseOutcome.idle,
      errorMessage: null,
    ),);
  }

  /// Purchase the currently selected plan. Translates [BillingResult]
  /// variants into UI state.
  Future<void> purchase() async {
    if (state.isLoading) return;
    emit(state.copyWith(
      isLoading: true,
      lastOutcome: PurchaseOutcome.pending,
      errorMessage: null,
    ),);

    final result = await _billing.purchase(state.selectedPlanId);
    await _applyResult(result);
  }

  /// Restore a previously purchased entitlement (used by the
  /// "Restore purchases" link).
  Future<void> restore() async {
    if (state.isLoading) return;
    emit(state.copyWith(
      isLoading: true,
      lastOutcome: PurchaseOutcome.pending,
      errorMessage: null,
    ),);
    final result = await _billing.restore();
    await _applyResult(result);
  }

  Future<void> _applyResult(BillingResult result) async {
    switch (result) {
      case BillingSuccess(
          :final planId,
          :final receiptId,
          :final trialActiveUntil,
        ):
        await _prefs.setPremiumDemo(true);
        await _prefs.setShowPremiumOffer(false);
        emit(state.copyWith(
          isLoading: false,
          isPremium: true,
          showPremiumOffer: false,
          selectedPlanId: planId,
          trialActiveUntil: trialActiveUntil,
          lastReceiptId: receiptId,
          lastOutcome: PurchaseOutcome.success,
        ),);
        // Mirror the entitlement onto the auth state so settings/profile
        // surfaces update without an app restart.
        await _mirrorUserPremium(true);
      case BillingCancelled():
        emit(state.copyWith(
          isLoading: false,
          lastOutcome: PurchaseOutcome.cancelled,
        ),);
      case BillingPending():
        emit(state.copyWith(
          isLoading: false,
          lastOutcome: PurchaseOutcome.pending,
        ),);
      case BillingError(:final message):
        emit(state.copyWith(
          isLoading: false,
          lastOutcome: PurchaseOutcome.error,
          errorMessage: message,
        ),);
    }
  }

  /// User dismissed the first-login paywall.
  Future<void> skipPremiumOffer() async {
    await _prefs.setShowPremiumOffer(false);
    emit(state.copyWith(showPremiumOffer: false),);
  }

  /// Clear the last outcome (e.g. after the user dismisses the error
  /// banner).
  void clearOutcome() {
    if (state.lastOutcome == PurchaseOutcome.idle) return;
    emit(state.copyWith(
      lastOutcome: PurchaseOutcome.idle,
      errorMessage: null,
    ),);
  }

  /// Dev-only override. Lets a build flag flip premium status without
  /// going through the billing provider. Never wired to UI.
  @visibleForTesting
  Future<void> setPremium(bool isPremium) async {
    await _prefs.setPremiumDemo(isPremium);
    emit(state.copyWith(isPremium: isPremium),);
  }

  Future<void> _mirrorUserPremium(bool value) async {
    final auth = _auth;
    if (auth == null) return;
    try {
      // The source of truth for premium is the Firestore
      // `users/{uid}.isPremium` field, written by a Cloud Function that
      // mirrors the store webhook. Until that lands, the AuthCubit user
      // model may keep its old `isPremium` — the upgrade screen paints
      // the right thing from the cubit's own state, and Settings reads
      // it from there too.
      await auth.refreshUser();
    } catch (_) {
      // Best-effort: the upgrade screen has already updated its own
      // state; the auth mirror can recover on next launch.
    }
  }
}
