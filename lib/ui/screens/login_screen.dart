import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../data/models/user_model.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/premium/premium_cubit.dart';
import '../../blocs/localization/localization_cubit.dart';
import '../../data/services/shared_prefs_service.dart';
import 'register_screen.dart';
import 'premium_offer_screen.dart';
import 'home_screen.dart';
import 'admin/admin_shell.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_durations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppDurations.entranceShort,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthCubit>().signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }
  }

  void _onGoogleSignIn() {
    context.read<AuthCubit>().signInWithGoogle();
  }

  /// Open a dialog that asks for the user's email and fires
  /// [AuthCubit.resetPassword]. The login screen's [BlocListener] picks
  /// up the resulting [AuthStatus.passwordResetSent] and shows the
  /// "check your inbox" SnackBar.
  ///
  /// [locState] is captured before the dialog opens so the dialog
  /// text doesn't need to read from a [BuildContext] across an await.
  /// We pre-fill the email field with whatever the user already typed
  /// into the login form, so the most common case (typo in their
  /// password) is one tap and one confirmation away from being fixed.
  Future<void> _showForgotPasswordDialog(LocalizationState locState) async {
    final initialEmail = _emailController.text.trim();
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ForgotPasswordDialog(
        initialEmail: initialEmail,
        authCubit: context.read<AuthCubit>(),
        localizationCubit: context.read<LocalizationCubit>(),
        locState: locState,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        // Capture the localization state up-front so the
        // password-reset branch can render the success SnackBar text
        // — the BlocListener's `context` is the same as the build
        // context's subtree, so reading LocalizationCubit here is
        // safe and avoids re-walking the widget tree on each emit.
        final listenerLoc =
            context.read<LocalizationCubit>().state;
        if (state.status == AuthStatus.authenticated) {
          // Check if user is admin - send to admin shell
          if (state.user?.role == UserRole.admin) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AdminShell()),
            );
            return;
          }

          // Non-admin users - check premium offer
          final premiumCubit = context.read<PremiumCubit>();
          // The post-login value-prop screen only appears for users who
          // have not yet heard any audio preview. Once they have, the
          // gated flag persists across sign-out by design.
          final showOffer =
              premiumCubit.state.showPremiumOffer &&
              !SharedPrefsService.instance.audioPreviewedAtLeastOnce;
          if (showOffer) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PremiumOfferScreen()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        } else if (state.status == AuthStatus.passwordResetSent) {
          // Password reset email was sent. Tell the user to check
          // their inbox; the user is *not* signed in so we stay on
          // the login screen.
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_tr(listenerLoc, 'password_reset_sent')),
            ),
          );
          // Flip the cubit back to a non-error idle state so the next
          // sign-in attempt isn't masked by the reset status.
          context.read<AuthCubit>().emitIdleAfterReset();
        } else if (state.status == AuthStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: BlocBuilder<LocalizationCubit, LocalizationState>(
        builder: (context, locState) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Logo
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: AppRadius.heroImageBorder,
                          boxShadow: AppShadows.heroLogoFor(
                            Theme.of(context).brightness,
                            shadowColor: context.semanticColors.shadow,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: AppRadius.heroImageBorder,
                          child: Image.asset(
                            'assets/images/logo.jpeg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        _tr(locState, 'login'),
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _tr(locState, 'welcome_subtitle'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Form Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: AppRadius.xlBorder,
                          boxShadow: AppShadows.heroLogoFor(
                            Theme.of(context).brightness,
                            shadowColor: context.semanticColors.shadow,
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTextField(
                                controller: _emailController,
                                label: _tr(locState, 'email'),
                                icon: PhosphorIconsRegular.envelopeSimple,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return _tr(locState, 'error_invalid_email');
                                  }
                                  if (!value.contains('@')) {
                                    return _tr(locState, 'error_invalid_email');
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _passwordController,
                                label: _tr(locState, 'password'),
                                icon: PhosphorIconsRegular.lock,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? PhosphorIconsRegular.eyeSlash
                                        : PhosphorIconsRegular.eye,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                  onPressed: () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return _tr(locState, 'error_weak_password');
                                  }
                                  return null;
                                },
                              ),
                              // "Forgot password?" — right-aligned
                              // under it. Pre-fills the email field if
                              // the user already typed one, so they
                              // don't retype it in the dialog.
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () =>
                                      _showForgotPasswordDialog(locState),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    _tr(locState, 'forgot_password'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              BlocBuilder<AuthCubit, AuthState>(
                                builder: (context, authState) {
                                  return SizedBox(
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed:
                                          authState.status == AuthStatus.loading
                                              ? null
                                              : _onLogin,
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child:
                                          authState.status == AuthStatus.loading
                                              ? SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      color:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .onPrimary,
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                              : Text(_tr(locState, 'login')),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'or',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildGoogleButton(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _tr(locState, 'no_account'),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed:
                                () => Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                ),
                            child: Text(
                              _tr(locState, 'register'),
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _tr(LocalizationState state, String key) {
    return state.translations[key] ?? key;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBorder,
          borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }

  Widget _buildGoogleButton() {
    // Mirror the email button's loading guard (see _buildEmailButton
    // above) so a quick double-tap on the Google button can't race two
    // credential exchanges. The cubit also short-circuits on
    // AuthStatus.loading, but the UI guard is what actually prevents
    // the second tap from firing.
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final isLoading = authState.status == AuthStatus.loading;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : _onGoogleSignIn,
            borderRadius: AppRadius.lgBorder,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
                borderRadius: AppRadius.lgBorder,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    // Brand-explicit Google red — kept literal so the
                    // sign-in badge stays consistent with Google's brand.
                    decoration: const BoxDecoration(
                      color: Color(0xFFD32F2F),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'G',
                        // White foreground over the brand-literal red pill
                        // — fixed-content, not theme-aware.
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (isLoading)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                        strokeWidth: 2,
                      ),
                    )
                  else
                    Text(
                      'Continue with Google',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Stateful dialog for the password-reset flow. Owns its own
/// [TextEditingController] and [GlobalKey<FormState>] so their lifetimes
/// match the dialog route exactly — the [LoginScreen] doesn't dispose
/// the controller from its `showDialog` scope, which previously raced
/// the dialog's unmount and produced "TextEditingController was used
/// after being disposed" rebuild errors when the cubit's emit
/// triggered a BlocBuilder rebuild mid-pop.
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.authCubit,
    required this.localizationCubit,
    required this.locState,
  });

  final String initialEmail;
  final AuthCubit authCubit;
  final LocalizationCubit localizationCubit;
  final LocalizationState locState;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    // Flutter disposes the TextField's listener chain during the
    // dialog's unmount. dispose() here runs *after* that — so the
    // controller has no live listeners at this point and Dispose
    // won't race a rebuild.
    _emailController.dispose();
    super.dispose();
  }

  String _tr(String key) =>
      widget.locState.translations[key] ?? key;

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    // Pop first so the dialog unmount fires before the cubit emits
    // `loading` (which the dialog's BlocBuilder would otherwise react
    // to mid-unmount).
    if (!mounted) return;
    Navigator.pop(context);
    await widget.authCubit.resetPassword(email);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: widget.authCubit),
        BlocProvider<LocalizationCubit>.value(value: widget.localizationCubit),
      ],
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (innerContext, authState) {
          final isLoading = authState.status == AuthStatus.loading;
          return AlertDialog(
            title: Text(_tr('forgot_password_title')),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _tr('forgot_password_body'),
                    style: Theme.of(innerContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isLoading,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: _tr('email'),
                      prefixIcon: Icon(
                        PhosphorIconsRegular.envelopeSimple,
                        color: Theme.of(innerContext).colorScheme.primary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.mdBorder,
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty ||
                          !value.contains('@')) {
                        return _tr('error_invalid_email');
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.pop(innerContext),
                child: Text(_tr('cancel')),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : _send,
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_tr('forgot_password_send')),
              ),
            ],
          );
        },
      ),
    );
  }
}
