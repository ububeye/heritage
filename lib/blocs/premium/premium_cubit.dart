import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/billing_provider.dart';
import '../../data/services/shared_prefs_service.dart';
import '../../data/services/tts_service.dart';
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
    TtsService? ttsService,
  }) : _billing = billing,
       _auth = auth,
       _prefs = prefs ?? SharedPrefsService.instance,
       _ttsService = ttsService,
       super(const PremiumState()) {
    _hydrateFromPrefs();
  }

  final BillingProvider _billing;
  final AuthCubit? _auth;
  final SharedPrefsService _prefs;
  final TtsService? _ttsService;

  /// Pull cached values from SharedPreferences so the screen paints with
  /// the right state on first frame. The BillingProvider call happens
  /// separately via [initialize].
  void _hydrateFromPrefs() {
    final uid = _auth?.state.user?.id;
    emit(
      state.copyWith(
        showPremiumOffer: _prefs.showPremiumOffer,
        // Per-user demo override. Defaults to false when the auth
        // cubit isn't wired yet (constructor-time) or when no user is
        // signed in — premium is re-evaluated on the next auth refresh.
        isPremium: uid != null ? _prefs.isPremiumDemoFor(uid) : false,
      ),
    );
  }

  /// App-start hook. Asks the billing provider for the authoritative
  /// entitlement. Resilient to the provider being slow: we don't block
  /// the splash screen, the cubit re-emits when the answer arrives.
  ///
  /// Late-emit guards: every `emit` after an `await` checks `isClosed`
  /// first. Without this, a logout / hot-restart while the billing SDK
  /// is in flight throws "Bad state: Cannot emit new states after
  /// calling close" and crashes the splash transition.
  Future<void> initialize() async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true, lastOutcome: PurchaseOutcome.idle));
    try {
      final entitlement = await _billing.currentEntitlement();
      if (isClosed) return;
      if (entitlement != null) {
        emit(
          state.copyWith(
            isLoading: false,
            isPremium: true,
            selectedPlanId: entitlement.planId,
            trialActiveUntil: entitlement.trialActiveUntil,
            lastReceiptId: entitlement.receiptId,
            lastOutcome: PurchaseOutcome.success,
          ),
        );
        // Push the upgrade onto the TTS engine so the next speak()
        // uses the unlimited chunk rather than the 30s preview.
        _ttsService?.setPremium(true);
      } else {
        emit(state.copyWith(isLoading: false));
      }
    } catch (e) {
      // Surface the error so the upgrade screen can show a banner
      // rather than silently leaving the user on a stale cached value.
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          lastOutcome: PurchaseOutcome.error,
          errorMessage: 'Could not verify entitlement: $e',
        ),
      );
    }
  }

  /// Plan card tap.
  void selectPlan(PlanId id) {
    if (state.selectedPlanId == id) return;
    emit(
      state.copyWith(
        selectedPlanId: id,
        lastOutcome: PurchaseOutcome.idle,
        errorMessage: null,
      ),
    );
  }

  /// Purchase the currently selected plan. Translates [BillingResult]
  /// variants into UI state.
  Future<void> purchase() async {
    if (state.isLoading) return;
    emit(
      state.copyWith(
        isLoading: true,
        lastOutcome: PurchaseOutcome.pending,
        errorMessage: null,
      ),
    );

    final result = await _billing.purchase(state.selectedPlanId);
    if (isClosed) return;
    await _applyResult(result);
  }

  /// Restore a previously purchased entitlement (used by the
  /// "Restore purchases" link).
  Future<void> restore() async {
    if (state.isLoading) return;
    emit(
      state.copyWith(
        isLoading: true,
        lastOutcome: PurchaseOutcome.pending,
        errorMessage: null,
      ),
    );
    final result = await _billing.restore();
    if (isClosed) return;
    await _applyResult(result);
  }

  Future<void> _applyResult(BillingResult result) async {
    switch (result) {
      case BillingSuccess(
        :final planId,
        :final receiptId,
        :final trialActiveUntil,
      ):
        // Persist the entitlement under the current user's uid so it
        // survives restarts and sign-out + sign-in on this device,
        // but never leaks to a different account on the same device.
        final userId = _auth?.state.user?.id;
        if (userId != null) {
          await _prefs.setPremiumDemoFor(userId, true);
        } else {
          // Unreachable in production: the upgrade screen requires
          // auth. Asserted so a future regression in the auth wiring
          // surfaces in debug builds instead of silently dropping the
          // persisted entitlement.
          assert(
            userId != null,
            'PremiumCubit: BillingSuccess fired without an authenticated user',
          );
        }
        await _prefs.setShowPremiumOffer(false);
        if (isClosed) return;
        emit(
          state.copyWith(
            isLoading: false,
            isPremium: true,
            showPremiumOffer: false,
            selectedPlanId: planId,
            trialActiveUntil: trialActiveUntil,
            lastReceiptId: receiptId,
            lastOutcome: PurchaseOutcome.success,
          ),
        );
        // Push the upgrade onto the TTS engine immediately so the
        // next speak() (e.g. the user replays the audio right after
        // buying) uses the unlimited chunk. Without this, the user
        // would still hear the 30s preview until they restart the app.
        _ttsService?.setPremium(true);
        // Flip the auth state so the 7 audio languages unlock
        // immediately on every screen that reads AuthState.isPremium.
        // We intentionally skip the post-purchase refreshUser()
        // round-trip here: there is no Cloud Function mirroring the
        // store webhook back to the user's role document yet, so
        // refreshUser() would resolve to role=free and overwrite the
        // optimistic flip within hundreds of ms. Guarded by the same
        // userId check as the prefs write above so the two stay in
        // sync — a uid-less flip without a prefs write would be a
        // phantom upgrade that evaporates on restart.
        if (isClosed) return;
        if (userId != null) _auth?.markUserPremiumOptimistic(true);
      case BillingCancelled():
        if (isClosed) return;
        emit(
          state.copyWith(
            isLoading: false,
            lastOutcome: PurchaseOutcome.cancelled,
          ),
        );
      case BillingPending():
        if (isClosed) return;
        emit(
          state.copyWith(
            isLoading: false,
            lastOutcome: PurchaseOutcome.pending,
          ),
        );
      case BillingError(:final message):
        if (isClosed) return;
        emit(
          state.copyWith(
            isLoading: false,
            lastOutcome: PurchaseOutcome.error,
            errorMessage: message,
          ),
        );
    }
  }

  /// User dismissed the first-login paywall.
  Future<void> skipPremiumOffer() async {
    await _prefs.setShowPremiumOffer(false);
    if (isClosed) return;
    emit(state.copyWith(showPremiumOffer: false));
  }

  /// Clear the last outcome (e.g. after the user dismisses the error
  /// banner).
  void clearOutcome() {
    if (state.lastOutcome == PurchaseOutcome.idle) return;
    emit(state.copyWith(lastOutcome: PurchaseOutcome.idle, errorMessage: null));
  }

  /// Dev-only override. Lets a build flag flip premium status without
  /// going through the billing provider. Never wired to UI. Persistence
  /// is intentionally a no-op here — production-grade tests inject their
  /// own prefs and a stale uid-keyed entry from this path would otherwise
  /// leak across test runs.
  @visibleForTesting
  Future<void> setPremium(bool isPremium) async {
    if (isClosed) return;
    emit(state.copyWith(isPremium: isPremium));
    _ttsService?.setPremium(isPremium);
  }
}
