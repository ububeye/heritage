import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../data/models/user_model.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/premium/premium_cubit.dart';
import '../../blocs/localization/localization_cubit.dart';
import 'login_screen.dart';
import 'premium_offer_screen.dart';
import 'home_screen.dart';
import 'admin/admin_shell.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_durations.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppDurations.entranceShort,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthCubit>().signUpWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
    }
  }

  void _onGoogleSignUp() {
    context.read<AuthCubit>().signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
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
          if (premiumCubit.state.showPremiumOffer) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PremiumOfferScreen()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        } else if (state.status == AuthStatus.error && state.errorMessage != null) {
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
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: AppRadius.heroImageBorder,
                          boxShadow: [
                            // TODO(#pr-follow-up): migrate to AppShadows.* with custom blur/offset
                            BoxShadow(
                              // Logo shadow — theme-aware.
                              color: context.semanticColors.shadow,
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
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
                        _tr(locState, 'register'),
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _tr(locState, 'welcome_subtitle'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.8),
                            ),
                      ),
                      const SizedBox(height: 40),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: AppRadius.xlBorder,
                            boxShadow: [
                              // TODO(#pr-follow-up): migrate to AppShadows.* with custom blur/offset
                              BoxShadow(
                                // Form-card shadow — theme-aware.
                                color: context.semanticColors.shadow,
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildTextField(
                                  controller: _emailController,
                                  label: _tr(locState, 'email'),
                                  icon: Icons.email_outlined,
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
                                  icon: Icons.lock_outlined,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                    onPressed: () {
                                      setState(() => _obscurePassword = !_obscurePassword);
                                    },
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return _tr(locState, 'error_weak_password');
                                    }
                                    if (value.length < 6) {
                                      return _tr(locState, 'error_weak_password');
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  controller: _confirmPasswordController,
                                  label: _tr(locState, 'confirm_password'),
                                  icon: Icons.lock_outlined,
                                  obscureText: _obscureConfirmPassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                    onPressed: () {
                                      setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                                    },
                                  ),
                                  validator: (value) {
                                    if (value != _passwordController.text) {
                                      return _tr(locState, 'error_password_mismatch');
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                BlocBuilder<AuthCubit, AuthState>(
                                  builder: (context, authState) {
                                    return SizedBox(
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: authState.status == AuthStatus.loading
                                            ? null
                                            : _onRegister,
                                        style: ElevatedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: AppRadius.lgBorder,
                                          ),
                                          elevation: 0,
                                        ),
                                        child: authState.status == AuthStatus.loading
                                            ? SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(
                                                  color: Theme.of(context).colorScheme.onPrimary,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : Text(_tr(locState, 'register')),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'or',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Theme.of(context).dividerColor)),
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
                              _tr(locState, 'have_account'),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              ),
                              child: Text(
                                _tr(locState, 'login'),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onGoogleSignUp,
        borderRadius: AppRadius.lgBorder,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
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
              Text(
                'Continue with Google',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
