import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/user_model.dart';
import '../../data/services/billing_provider.dart';
import '../../data/services/firestore_service.dart';
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
    FirestoreService? firestore,
  }) : _billing = billing,
       _auth = auth,
       _prefs = prefs ?? SharedPrefsService.instance,
       _ttsService = ttsService,
       _firestore = firestore ?? FirestoreService(),
       super(const PremiumState()) {
    _hydrateFromPrefs();
  }

  final BillingProvider _billing;
  final AuthCubit? _auth;
  final SharedPrefsService _prefs;
  final TtsService? _ttsService;
  // Used to mirror the locally-promoted premium status onto the canonical
  // server-side `roles/{uid}` document the Admin User Management screen
  // reads from. Without this write, the admin would keep seeing the user
  // as 'free' after a successful purchase — see firestore.rules for the
  // self-promotion allowlist that gates it.
  final FirestoreService _firestore;

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
        // round-trip here: refreshUser() would resolve to role=free
        // and overwrite the optimistic flip within hundreds of ms
        // unless the role doc has been updated first.
        // Guarded by the same userId check as the prefs write above so
        // the two stay in sync — a uid-less flip without a prefs write
        // would be a phantom upgrade that evaporates on restart.
        if (isClosed) return;
        if (userId != null) {
          _auth?.markUserPremiumOptimistic(true);
          // Server-side mirror. The Admin User Management screen
          // (`lib/ui/screens/admin/admin_user_management_screen.dart`)
          // derives premium counts from `roles/{uid}`, not from
          // SharedPreferences, so without this write the admin would
          // keep seeing the freshly-subscribed user as 'free' until
          // they manually promoted them. We do it best-effort — the
          // optimistic local flip above means the buying device has
          // already unlocked premium features; a failed Firestore
          // write degrades gracefully into 'admin sees free until next
          // refresh', which was the prior behavior anyway. The
          // firestore.rules self-promotion guard limits what this
          // call can do (must target your own uid; only role='premium';
          // only from free or no-doc).
          await _persistPremiumEntitlement(
            userId: userId,
            planId: planId,
            trialActiveUntil: trialActiveUntil,
          );
        }
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

  /// Mirror a successful purchase onto the canonical Firestore doc(s)
  /// the admin UI reads from. Best-effort; a thrown error here is
  /// swallowed because the in-memory `markUserPremiumOptimistic` flip
  /// and the SharedPreferences write have already unlocked premium for
  /// the buying device. The admin will simply see this user as 'free'
  /// until they refresh — strictly better than the previous behavior,
  /// which kept the user invisible to admin *forever*.
  ///
  /// Writes:
  ///   * `roles/{uid}` — set to 'premium' (gated by the self-promotion
  ///     rule in firestore.rules).
  ///   * `users/{uid}.subscription_expiry` — ISO 8601, used by
  ///     `UserCubit.loadUsers` as a fallback premium indicator when
  ///     no `roles/{uid}` doc exists. Lifetime purchases get a 100-year
  ///     sentinel; trials get the trial end; all other plans get null
  ///     so admin doesn't see the user flipping back to free after
  ///     the visible trial ends.
  Future<void> _persistPremiumEntitlement({
    required String userId,
    required PlanId planId,
    required DateTime? trialActiveUntil,
  }) async {
    try {
      await _firestore.setUserRole(userId, UserRole.premium);
      // Plan-default expiry. A live trial window always overrides the
      // plan-default — admins and the fallback premium detector should
      // see the earlier trial-end date while the trial is active.
      final now = DateTime.now();
      final planExpiry = switch (planId) {
        // 100 years out — never auto-expires; admin can see the
        // definitive "lifetime" stamp via selectedPlanId we already
        // wrote elsewhere if needed.
        PlanId.lifetime => now.add(const Duration(days: 365 * 100)),
        PlanId.monthly || PlanId.proMonthly => now.add(
          const Duration(days: 31),
        ),
        PlanId.yearly || PlanId.proYearly => now.add(
          const Duration(days: 366),
        ),
      };
      final trialEnd =
          trialActiveUntil != null && trialActiveUntil.isAfter(now)
              ? trialActiveUntil
              : null;
      final expiry = trialEnd != null && trialEnd.isBefore(planExpiry)
          ? trialEnd
          : planExpiry;
      await _firestore.setUserSubscriptionExpiry(userId, expiry);
    } catch (e) {
      // Swallowed deliberately — see method doc.
      debugPrint('PremiumCubit: failed to mirror premium to Firestore: $e');
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
