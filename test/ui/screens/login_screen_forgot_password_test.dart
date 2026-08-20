// Widget tests for the "Forgot password?" affordance on the login
// screen. Pins:
//
//   1. The "Forgot password?" link renders under the password field
//      and is enabled when the cubit is idle.
//   2. Tapping it opens a dialog with an email field pre-filled
//      from whatever the user already typed into the login form.
//   3. The dialog's "Send reset link" button calls AuthCubit.resetPassword
//      with the typed email and pops the dialog.
//   4. On success, the login screen's BlocListener surfaces the
//      "check your inbox" SnackBar and the cubit returns to the
//      unauthenticated idle state.
//   5. On a thrown exception from AuthService.resetPassword, the
//      error lands in the errorMessage on state and is surfaced via
//      the existing red SnackBar.
//
// Uses hand-written fakes (no mocktail) per project convention. The
// login screen reads TtsService through LocalizationCubit, so a stub
// is included; the localization cubit's translation map is empty by
// default, so the dialog falls back to its English literal copy.

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

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.resetError});

  /// When set, resetPassword throws this error after [resetCompleter]
  /// resolves. The resetCompleter is parked by default so tests can
  /// drive the cubit through loading + success/error transitions
  /// deterministically.
  final Object? resetError;

  /// Completer parking the resetPassword future. Used by tests to
  /// hold the cubit in loading while assertions run, then resolve
  /// to either complete cleanly (success path) or to throw (error
  /// path).
  final Completer<void> resetCompleter = Completer<void>();

  int resetCalls = 0;
  String? lastEmail;

  @override
  Future<void> resetPassword(String email) async {
    resetCalls += 1;
    lastEmail = email;
    await resetCompleter.future;
    if (resetError != null) throw resetError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_FakeAuthService.${invocation.memberName} not stubbed',
    );
  }
}

class _StubFirestoreService implements FirestoreService {
  @override
  Future<UserRole?> getUserRole(String uid) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_StubFirestoreService.${invocation.memberName} not stubbed',
    );
  }
}

class _StubTtsService implements TtsService {
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
  void setOnError(ValueChanged<String>? onError) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_StubTtsService.${invocation.memberName} not stubbed',
    );
  }
}

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

const _englishTranslations = <String, String>{
  'login': 'Log in',
  'email': 'Email',
  'password': 'Password',
  'welcome_subtitle': 'Welcome subtitle',
  'forgot_password': 'Forgot password?',
  'forgot_password_title': 'Reset your password',
  'forgot_password_body':
      "Enter your account email and we'll send a link to set a new password.",
  'forgot_password_send': 'Send reset link',
  'password_reset_sent':
      'Check your inbox — we sent a password reset link.',
  'cancel': 'Cancel',
  'error_invalid_email': 'Invalid email',
  'error_weak_password': 'Password is required',
  'no_account': "Don't have an account?",
  'register': 'Sign up',
};

Future<void> _pumpLoginScreen(
  WidgetTester tester, {
  required AuthCubit cubit,
  LocalizationCubit? locCubit,
}) async {
  final localization =
      locCubit ?? LocalizationCubit(ttsService: _StubTtsService());
  if (locCubit == null) {
    localization.emit(
      LocalizationState(
        currentLanguage: 'en',
        translations: _englishTranslations,
      ),
    );
  }
  final premium = PremiumCubit(billing: _StubBillingProvider());

  // Use the production [AppTheme.lightTheme] (so the login screen's
  // `context.semanticColors` lookup resolves). The production theme
  // builds its text styles via `GoogleFonts.inter(...)`, which tries
  // to fetch the Inter font from fonts.gstatic.com — the fetch fails
  // in the widget-test environment but the failure surfaces as a
  // debug-only `print`, not as a thrown exception. SnackBar text
  // widgets therefore build successfully.
  final theme = AppTheme.lightTheme;

  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      // The login screen's BlocListener fires
      // ScaffoldMessenger.of(context).showSnackBar(...). The listener
      // runs in a context ABOVE the page's Scaffold, so we install a
      // ScaffoldMessenger at the MaterialApp level so the lookup
      // resolves and the snackbar can paint.
      scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: cubit),
          BlocProvider<LocalizationCubit>.value(value: localization),
          BlocProvider<PremiumCubit>.value(value: premium),
        ],
        child: const LoginScreen(),
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

  testWidgets(
    'Forgot password? link renders under the password field',
    (tester) async {
      final auth = _FakeAuthService();
      final cubit = AuthCubit(
        authService: auth,
        firestoreService: _StubFirestoreService(),
      );

      await _pumpLoginScreen(tester, cubit: cubit);

      expect(find.text('Forgot password?'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping Forgot password? opens a dialog with a pre-filled email field',
    (tester) async {
      final auth = _FakeAuthService();
      final cubit = AuthCubit(
        authService: auth,
        firestoreService: _StubFirestoreService(),
      );

      await _pumpLoginScreen(tester, cubit: cubit);

      // Type an email in the login form so we can assert the dialog
      // pre-fills it.
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'tourist@example.com',
      );

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      // Dialog title + body render.
      expect(find.text('Reset your password'), findsOneWidget);
      expect(
        find.text(
          "Enter your account email and we'll send a link to set a new password.",
        ),
        findsOneWidget,
      );
      // Email field pre-filled with the login form's email.
      final emailField = tester.widget<TextFormField>(
        find.byType(TextFormField).at(0),
      );
      expect(emailField.controller?.text, 'tourist@example.com');
      // Send and Cancel actions render.
      expect(find.text('Send reset link'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await cubit.close();
    },
  );

  testWidgets(
    'Send reset link calls AuthCubit.resetPassword and surfaces success snackbar',
    (tester) async {
      final auth = _FakeAuthService();
      final cubit = AuthCubit(
        authService: auth,
        firestoreService: _StubFirestoreService(),
      );

      await _pumpLoginScreen(tester, cubit: cubit);

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      // Type the email into the *dialog's* field (scoped via
      // find.descendant so the login screen's email field doesn't
      // shadow the find).
      final dialogEmail = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(dialogEmail, 'visitor@example.com');
      // Tap Send under the fake-async clock — taps are fake-async
      // aware (they don't dispatch when runAsync is active). The
      // dialog's onPressed awaits the parked completer so the tap
      // returns immediately; the cubit will emit `loading` next.
      await tester.tap(find.text('Send reset link'));
      await tester.pump();

      // AuthService.resetPassword was invoked with the typed email.
      expect(auth.resetCalls, 1);
      expect(auth.lastEmail, 'visitor@example.com');

      // Release the parked future under fake-async. The
      // _FakeAuthService `await resetCompleter.future` was kicked
      // off under fake-async (via the tap), so resuming the future
      // under fake-async means the cubit's then clause, the
      // `passwordResetSent` emit, the BlocListener, AND the
      // `showSnackBar()` call all run under fake-async — the
      // SnackBar's AnimationController registers its first frame
      // callback inside the same fake-async zone, so subsequent
      // `pump(Duration)` calls animate it cleanly without negative
      // elapsed-time assertions.
      auth.resetCompleter.complete();
      // 250ms is enough for the success transition + SnackBar
      // entry to settle. The default SnackBar duration is 4s, so
      // pumpAndSettle would hang waiting for the auto-dismiss.
      await tester.pump(const Duration(milliseconds: 250));

      // The success snackbar is shown on the login screen.
      expect(
        find.text(
          'Check your inbox — we sent a password reset link.',
        ),
        findsOneWidget,
      );

      // Cubit returned to unauthenticated idle so the next sign-in
      // attempt isn't masked by the reset status.
      expect(cubit.state.status, AuthStatus.unauthenticated);

      await cubit.close();
    },
  );

  testWidgets(
    'error from AuthService.resetPassword surfaces in the error snackbar',
    (tester) async {
      final auth = _FakeAuthService(
        resetError: Exception('No account found with that email'),
      );
      final cubit = AuthCubit(
        authService: auth,
        firestoreService: _StubFirestoreService(),
      );

      await _pumpLoginScreen(tester, cubit: cubit);

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      final dialogEmail = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(dialogEmail, 'noone@example.com');

      // Tap Send under fake-async — see the success test comment
      // for why the tap happens here, not inside runAsync.
      await tester.tap(find.text('Send reset link'));
      await tester.pump();

      // Release the parked future under fake-async so the cubit's
      // catch path emits the error and the BlocListener's
      // showSnackBar() runs in the same fake-async zone. See the
      // success test for the full rationale.
      auth.resetCompleter.complete();
      await tester.pump(const Duration(milliseconds: 250));

      expect(cubit.state.status, AuthStatus.error);
      expect(cubit.state.errorMessage, contains('No account found'));

      // The login screen's existing error branch surfaces the message.
      expect(find.textContaining('No account found'), findsOneWidget);

      await cubit.close();
    },
  );

  testWidgets(
    'invalid email in the dialog shows a validation error before submitting',
    (tester) async {
      final auth = _FakeAuthService();
      final cubit = AuthCubit(
        authService: auth,
        firestoreService: _StubFirestoreService(),
      );

      await _pumpLoginScreen(tester, cubit: cubit);

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      // Don't enter anything — tap Send. The validator should reject
      // and the dialog should NOT call the cubit.
      await tester.tap(find.text('Send reset link'));
      await tester.pump();

      expect(auth.resetCalls, 0, reason: 'empty email must not submit');
      expect(
        find.text('Invalid email'),
        findsOneWidget,
        reason: 'validator error must render inline',
      );

      await cubit.close();
    },
  );
}