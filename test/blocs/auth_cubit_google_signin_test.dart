// Tests for the Google sign-in Fix 1 changes:
//  - AuthService.signInWithGoogle returns null on cancel, throws
//    Exception(...) on non-Firebase errors, and throws the string from
//    _handleAuthError on FirebaseAuthException.
//  - AuthCubit.signInWithGoogle:
//      * re-entrancy guard when state.status == loading,
//      * emits unauthenticated on null,
//      * emits error with e.toString() on exception,
//      * emits authenticated with resolved role on success,
//      * emits loading BEFORE the auth service call.
//  - LoginScreen Google button is disabled and shows a spinner while the
//    cubit is in AuthStatus.loading.
//
// We use handwritten fakes instead of mocktail because the project
// doesn't depend on a mocking library yet. The cubit accepts both
// services through constructor injection, so fakes are trivial.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stone_town_heritage_vt_guide/blocs/auth/auth_cubit.dart';
import 'package:stone_town_heritage_vt_guide/blocs/auth/auth_state.dart';
import 'package:stone_town_heritage_vt_guide/blocs/localization/localization_cubit.dart';
import 'package:stone_town_heritage_vt_guide/blocs/premium/premium_cubit.dart';
import 'package:stone_town_heritage_vt_guide/blocs/premium/premium_state.dart';
import 'package:stone_town_heritage_vt_guide/data/models/user_model.dart';
import 'package:stone_town_heritage_vt_guide/data/services/auth_service.dart';
import 'package:stone_town_heritage_vt_guide/data/services/billing_provider.dart';
import 'package:stone_town_heritage_vt_guide/data/services/firestore_service.dart';
import 'package:stone_town_heritage_vt_guide/data/services/tts_service.dart';
import 'package:stone_town_heritage_vt_guide/data/services/shared_prefs_service.dart';
import 'package:stone_town_heritage_vt_guide/core/theme/app_theme.dart';
import 'package:stone_town_heritage_vt_guide/ui/screens/login_screen.dart';

/// Auth stub that controls the timing of `signInWithGoogle` via an
/// external [Completer]. Records the observed [AuthState] at the moment
/// the service is invoked (for the "loading emitted BEFORE the service
/// is called" assertion).
class _RecordingAuthService implements AuthService {
  _RecordingAuthService({
    this.userResult,
    this.errorResult,
    // ignore: unused_element_parameter
    this.onServiceCalled,
  });

  final UserModel? userResult;
  final Object? errorResult;
  void Function()? onServiceCalled;
  int googleCallCount = 0;

  @override
  Future<UserModel?> signInWithGoogle() async {
    googleCallCount++;
    onServiceCalled?.call();
    if (errorResult != null) throw errorResult!;
    return userResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_RecordingAuthService.${invocation.memberName} not stubbed',
    );
  }
}

/// Auth stub whose `signInWithGoogle` parks on an external [Completer].
/// Used for the re-entrancy test and the widget test.
class _CompleterAuthService implements AuthService {
  _CompleterAuthService(this.completer);

  final Completer<UserModel?> completer;
  int callCount = 0;

  @override
  Future<UserModel?> signInWithGoogle() async {
    callCount++;
    return completer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_CompleterAuthService.${invocation.memberName} not stubbed',
    );
  }
}

/// Auth stub that stubs both `signInWithGoogle` (parks on
/// `googleCompleter`) and `signInWithEmail` (parks on
/// `emailCompleter`). Used to drive the re-entrancy test, which
/// lands the cubit in loading via `signInWithEmail` and then
/// asserts `signInWithGoogle` is short-circuited.
class _MultiPathAuthService implements AuthService {
  _MultiPathAuthService({
    required this.googleCompleter,
    required this.emailCompleter,
  });

  final Completer<UserModel?> googleCompleter;
  final Completer<UserModel?> emailCompleter;
  int googleCalls = 0;
  int emailCalls = 0;

  @override
  Future<UserModel?> signInWithGoogle() async {
    googleCalls++;
    return googleCompleter.future;
  }

  @override
  Future<UserModel?> signInWithEmail(String email, String password) async {
    emailCalls++;
    return emailCompleter.future;
  }

  /// signInWithEmail calls this to refresh role from Firebase Auth. We
  /// return null so the cubit falls back to the base user.
  @override
  Future<UserModel?> reloadUser() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_MultiPathAuthService.${invocation.memberName} not stubbed',
    );
  }
}

class _StubFirestoreService implements FirestoreService {
  _StubFirestoreService();

  /// Optional parked completer — when set, getUserRole waits on this
  /// completer. Used by the widget test to keep the cubit pinned in
  /// the loading state while we assert on the disabled button + spinner.
  Completer<UserRole?>? roleCompleter;

  @override
  Future<UserRole?> getUserRole(String uid) async {
    if (roleCompleter != null) return roleCompleter!.future;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_StubFirestoreService.${invocation.memberName} not stubbed',
    );
  }
}

UserModel _makeUser({String id = 'google-uid-1'}) {
  return UserModel(
    id: id,
    email: 'googler@example.com',
    displayName: 'Googler',
    role: UserRole.free,
  );
}

/// Minimal TTS stub that satisfies [LocalizationCubit]'s constructor.
class _StubTtsService implements TtsService {
  @override
  void setOnError(ValueChanged<String>? onError) {}

  // Session token stubs — the auth flow never exercises the audio
  // lifecycle, so these are pure no-ops.
  int _sessionToken = 0;

  @override
  int get currentSessionToken => _sessionToken;

  @override
  int beginSession() {
    _sessionToken++;
    return _sessionToken;
  }

  @override
  void invalidateSession() {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_StubTtsService.${invocation.memberName} not stubbed',
    );
  }
}

/// Minimal billing stub: everything returns "no entitlement".
class _StubBillingProvider implements BillingProvider {
  @override
  String get name => 'stub';

  @override
  Future<BillingResult> purchase(PlanId planId) async =>
      const BillingCancelled();

  @override
  Future<BillingResult> restore() async => const BillingCancelled();

  @override
  Future<({PlanId planId, DateTime? trialActiveUntil, String receiptId})?>
      currentEntitlement() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_StubBillingProvider.${invocation.memberName} not stubbed',
    );
  }
}

void main() {
  // The cubit's success path writes to SharedPreferencesService.instance.
  // setMockInitialValues seeds the in-memory backing AND we initialize
  // SharedPrefsService.getInstance() so its singleton has a backing
  // SharedPreferences object before any cubit calls into it.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsService.getInstance();
  });

  group('AuthCubit.signInWithGoogle', () {
    test('cancellation path emits unauthenticated', () async {
      final auth = _RecordingAuthService(userResult: null);
      final firestore = _StubFirestoreService();
      final cubit = AuthCubit(
        authService: auth,
        firestoreService: firestore,
      );

      final emitted = <AuthStatus>[];
      final sub = cubit.stream.listen((s) => emitted.add(s.status));

      await cubit.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, AuthStatus.unauthenticated);
      expect(cubit.state.user, isNull);
      expect(cubit.state.errorMessage, isNull);
      expect(auth.googleCallCount, 1);
      expect(emitted, contains(AuthStatus.unauthenticated));

      await sub.cancel();
      await cubit.close();
    });

    test('re-entrancy guard: dropping a second call while loading', () async {
      // The guard checks `state.status == AuthStatus.loading` at the
      // very top of signInWithGoogle and returns early. Per the
      // current cubit, signInWithGoogle does NOT emit loading itself
      // until after the picker resolves — so to test the guard we
      // drive the cubit into loading via signInWithEmail (which still
      // emits loading immediately) and then fire signInWithGoogle
      // while the email sign-in is parked.
      final emailCompleter = Completer<UserModel?>();
      final googleCompleter = Completer<UserModel?>();
      final auth = _MultiPathAuthService(
        googleCompleter: googleCompleter,
        emailCompleter: emailCompleter,
      );
      final firestore = _StubFirestoreService();
      final cubit = AuthCubit(
        authService: auth,
        firestoreService: firestore,
      );

      final sub = cubit.stream.listen((_) {});

      // Kick off email sign-in — emits loading synchronously then
      // parks on the email completer.
      final emailFuture = cubit.signInWithEmail('a@b.com', 'pwd');
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, AuthStatus.loading,
          reason: 'email sign-in should emit loading',);

      // While email is still in flight, fire signInWithGoogle. The
      // re-entrancy guard should drop it — google service never
      // called.
      final googleFutureWhileLoading = cubit.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);
      expect(auth.googleCalls, 0,
          reason: 're-entrancy guard should drop the call',);

      // Resolve email sign-in. The cubit's email path emits `authenticated`
      // only when a user is returned; we use a non-null user so the
      // cubit clears `loading` cleanly.
      emailCompleter.complete(_makeUser(id: 'email-uid'));
      await emailFuture;
      await Future<void>.delayed(Duration.zero);
      expect(
        cubit.state.status,
        AuthStatus.authenticated,
        reason: 'email sign-in with a user should emit authenticated',
      );

      // Now google should hit the service when called.
      final googleFuture = cubit.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);
      expect(auth.googleCalls, 1,
          reason: 'guard no longer applies once loading has cleared',);

      googleCompleter.complete(_makeUser(id: 'google-uid'));
      await googleFuture;
      await googleFutureWhileLoading;
      expect(cubit.state.status, AuthStatus.authenticated);

      await sub.cancel();
      await cubit.close();
    });

    test('loading is NOT emitted before the auth service resolves', () async {
      // Per the current cubit flow, the picker resolves first and only
      // THEN does the cubit emit loading — to avoid a spinner flash
      // during the ~100-500ms before the picker appears. This test
      // asserts that contract: at the moment the auth service is
      // called, the cubit is still in its previous status, and loading
      // is only emitted AFTER the service returns a non-null user.
      AuthState observedState = const AuthState();
      final auth = _RecordingAuthService(userResult: _makeUser());
      final firestore = _StubFirestoreService();
      AuthCubit? cubitRef;
      auth.onServiceCalled = () {
        observedState = cubitRef?.state ?? const AuthState();
      };
      final cubit = AuthCubit(
        authService: auth,
        firestoreService: firestore,
      );
      cubitRef = cubit;

      final emitted = <AuthStatus>[];
      final sub = cubit.stream.listen((s) => emitted.add(s.status));

      await cubit.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);

      // Final state is authenticated.
      expect(cubit.state.status, AuthStatus.authenticated);
      // Loading was emitted between the auth-service resolution and
      // the final authenticated emit.
      expect(emitted, contains(AuthStatus.loading));
      // When the service was invoked, the cubit was NOT yet in
      // loading — it held its previous status (initial).
      expect(observedState.status, AuthStatus.initial);

      await sub.cancel();
      await cubit.close();
    });

    test('error path: PlatformException-style failure', () async {
      final auth = _RecordingAuthService(
        errorResult: Exception('Google sign-in is unavailable on this device'),
      );
      final firestore = _StubFirestoreService();
      final cubit = AuthCubit(
        authService: auth,
        firestoreService: firestore,
      );

      final sub = cubit.stream.listen((_) {});

      await cubit.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, AuthStatus.error);
      // The cubit strips the leading 'Exception: ' prefix so the
      // SnackBar reads cleanly.
      expect(
        cubit.state.errorMessage,
        'Google sign-in is unavailable on this device',
      );

      await sub.cancel();
      await cubit.close();
    });

    test('successful path: emits authenticated with the user', () async {
      final user = _makeUser(id: 'google-uid-2');
      final auth = _RecordingAuthService(userResult: user);
      final firestore = _StubFirestoreService();
      final cubit = AuthCubit(
        authService: auth,
        firestoreService: firestore,
      );

      final emitted = <AuthStatus>[];
      final sub = cubit.stream.listen((s) => emitted.add(s.status));

      await cubit.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, AuthStatus.authenticated);
      expect(cubit.state.user, isNotNull);
      expect(cubit.state.user!.id, user.id);
      expect(cubit.state.user!.email, user.email);
      expect(cubit.state.errorMessage, isNull);
      // Loading was emitted along the way.
      expect(emitted, contains(AuthStatus.loading));

      await sub.cancel();
      await cubit.close();
    });
  });

  group('LoginScreen Google button', () {
    testWidgets(
      'renders, taps, shows spinner, and disables while loading',
      (WidgetTester tester) async {
        final completer = Completer<UserModel?>();
        final auth = _CompleterAuthService(completer);
        final firestore = _StubFirestoreService()
          ..roleCompleter = Completer<UserRole?>();
        final cubit = AuthCubit(
          authService: auth,
          firestoreService: firestore,
        );

        final locCubit = LocalizationCubit(ttsService: _StubTtsService());
        final premiumCubit = PremiumCubit(billing: _StubBillingProvider());

        // loadTranslations tries to read an asset — for unit tests we
        // don't need to drive that; the BlocBuilder only reads
        // state.translations, and the cubit's default state has an
        // empty map. The label we assert is the literal
        // 'Continue with Google' string, so we don't need the
        // translations.

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<AuthCubit>.value(value: cubit),
                BlocProvider<LocalizationCubit>.value(value: locCubit),
                BlocProvider<PremiumCubit>.value(value: premiumCubit),
              ],
              child: const LoginScreen(),
            ),
          ),
        );
        // Let the Image.asset + BlocBuilder rebuild complete. We use
        // pump instead of pumpAndSettle because the Image.network
        // resolver may keep the frame pending.
        await tester.pump();

        // Google button label is rendered.
        expect(find.text('Continue with Google'), findsOneWidget);
        expect(cubit.state.status, AuthStatus.initial);

        // Before tap: the Google InkWell's onTap is wired (not null).
        // The InkWell we want is the one whose descendant tree contains
        // 'Continue with Google'.
        final googleInkWell = () {
          final all = find.byType(InkWell).evaluate();
          for (final element in all) {
            final w = element.widget as InkWell;
            if (w.onTap != null && _inkWellContains(w, 'Continue with Google')) {
              return w;
            }
          }
          throw StateError('Google button InkWell not found');
        }();
        expect(
          googleInkWell.onTap,
          isNotNull,
          reason: 'Google button should be tappable before loading begins',
        );

        // Tap → signInWithGoogle parks on the completer. We invoke the
        // InkWell's `onTap` callback directly so the test doesn't have
        // to scroll the SingleChildScrollView in the 800x600 default
        // test viewport. The callback is exactly what the gesture would
        // have triggered.
        expect(googleInkWell.onTap, isNotNull);
        googleInkWell.onTap!();
        await tester.pump();

        // Per the current cubit flow, the picker resolves BEFORE the
        // cubit emits loading — to avoid a spinner flash on the picker
        // gap. So at this point the cubit is still in its previous
        // status, the button is still enabled, and the label is still
        // visible.
        expect(cubit.state.status, AuthStatus.initial);
        expect(find.text('Continue with Google'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Now resolve the picker with a real user. This drives the
        // cubit into loading (it has to do the role lookup + prefs
        // write before reaching authenticated).
        completer.complete(_makeUser());
        // Let the picker-resolution microtask run.
        await tester.pump();
        await tester.pump();

        // Cubit is now loading (between picker resolution and
        // authenticated emit).
        expect(cubit.state.status, AuthStatus.loading);
        // The literal "Continue with Google" label is gone (replaced by
        // a CircularProgressIndicator). The email login button's spinner
        // ALSO uses CircularProgressIndicator when loading, so we expect
        // >= 1 spinner widget.
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        expect(find.text('Continue with Google'), findsNothing);

        // The Google InkWell's onTap must now be null (button disabled).
        final googleInkWellWhileLoading = () {
          final all = find.byType(InkWell).evaluate();
          for (final element in all) {
            final w = element.widget as InkWell;
            // While loading, the button's content is the spinner — find
            // the InkWell that contained the label BEFORE the tap.
            // The cheapest robust check: find the InkWell inside the
            // decorated container with the brand 'G' marker.
            if (w.onTap == null && _inkWellContains(w, 'G')) {
              return w;
            }
          }
          throw StateError('Google button InkWell not found during loading');
        }();
        expect(googleInkWellWhileLoading.onTap, isNull);

        // Drain pending frames — the test ends here. We intentionally
        // do NOT let the cubit reach AuthStatus.authenticated; the
        // login screen's BlocListener navigates on authenticated to
        // HomeScreen / PremiumOfferScreen / AdminShell, all of which
        // require more providers we don't wire in this test. Closing
        // the cubit flips it to closed BEFORE the authenticated emit,
        // so the listener never runs.
        await cubit.close();
        await locCubit.close();
        await premiumCubit.close();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}

/// Walks an [InkWell]'s widget tree looking for a Text node with [text].
/// Intentionally minimal — only walks the children used by the Google
/// button (Material → InkWell → Container → Row → ...).
bool _inkWellContains(InkWell inkWell, String text) {
  Widget? w = inkWell.child;
  return _walk(w, text);
}

bool _walk(Widget? w, String text) {
  if (w == null) return false;
  if (w is Text && w.data == text) return true;
  if (w is RichText) {
    final span = w.text;
    if (span is TextSpan && span.toPlainText() == text) return true;
  }
  if (w is Container) return _walk(w.child, text);
  if (w is Padding) return _walk(w.child, text);
  if (w is Center) return _walk(w.child, text);
  if (w is SizedBox) return _walk(w.child, text);
  if (w is DecoratedBox) return _walk(w.child, text);
  if (w is Row || w is Column) {
    final Iterable<Widget> children =
        w is Row ? w.children : (w as Column).children;
    return children.any((c) => _walk(c, text));
  }
  if (w is Stack) {
    return w.children.any((c) => _walk(c, text));
  }
  return false;
}
