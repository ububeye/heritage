import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../blocs/auth/auth_cubit.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/premium/premium_cubit.dart';
import '../../blocs/premium/premium_state.dart';
import 'login_screen.dart';
import '../navigation/upgrade_navigator.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/user_model.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper: human-readable plan name from PlanId
// ─────────────────────────────────────────────────────────────────────────────
String _planDisplayName(PlanId id) {
  switch (id) {
    case PlanId.monthly:
      return 'Explorer Monthly';
    case PlanId.yearly:
      return 'Explorer Yearly';
    case PlanId.proMonthly:
      return 'Pro Monthly';
    case PlanId.proYearly:
      return 'Pro Yearly';
    case PlanId.lifetime:
      return 'Lifetime';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UserProfileScreen
// ─────────────────────────────────────────────────────────────────────────────
class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final user = authState.user;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Profile'),
          ),
          body: ListView(
            padding: AppInsets.card,
            children: [
              // ── Profile Header ─────────────────────────────────────────
              _buildProfileHeader(context, user),
              const SizedBox(height: 24),

              // ── Account Section ────────────────────────────────────────
              _SectionTitle(title: 'Account'),
              _SettingsCard(
                children: [
                  _ProfileMenuItem(
                    icon: PhosphorIconsRegular.user,
                    title: 'Edit Profile',
                    subtitle: 'Change name and photo',
                    onTap: () => _showEditProfileDialog(context, authState),
                  ),
                  const Divider(height: 1),
                  _ProfileMenuItem(
                    icon: PhosphorIconsRegular.lock,
                    title: 'Change Password',
                    subtitle:
                        authState.user?.signInProvider == SignInProvider.google
                            ? 'Reset via email (Google sign-in)'
                            : 'Update your password',
                    onTap: () => _showChangePasswordDialog(context, authState),
                  ),
                  // Language row removed — language settings live on the
                  // Settings screen, which is the single source of truth.
                ],
              ),
              const SizedBox(height: 24),

              // ── Subscription Section ───────────────────────────────────
              _SectionTitle(title: 'Subscription'),
              // Reads PremiumCubit for plan details (plan name, trial date,
              // receipt id) on top of AuthState.isPremium for the gate.
              BlocBuilder<PremiumCubit, PremiumState>(
                builder: (context, premiumState) {
                  if (authState.isPremium) {
                    return _ActiveSubscriptionCard(
                      authState: authState,
                      premiumState: premiumState,
                    );
                  }
                  return _UpgradePromptCard();
                },
              ),
              const SizedBox(height: 24),

              // ── App Info ───────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      'Stone Town Guide v1.0.0',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Made with ❤️ for Zanzibar',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: AppShadows.lowFor(Theme.of(context).brightness),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.1),
            backgroundImage:
                user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
            child:
                user?.photoUrl == null
                    ? Text(
                      user?.email[0].toUpperCase() ?? 'U',
                      style: Theme.of(
                        context,
                      ).textTheme.displayMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    )
                    : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? user?.email ?? 'User',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: AppInsets.pillTight,
                  decoration: BoxDecoration(
                    // Use `secondary` as the tint to mirror the
                    // settings-screen _PlanBadge. The previous version
                    // used `onPrimary.withValues(alpha:0.2)` which
                    // renders as a near-transparent patch on the card
                    // surface in both light and dark themes.
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.15),
                    borderRadius: AppRadius.mdBorder,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    user?.role.name.toUpperCase() ?? 'FREE',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthState authState) {
    final nameController = TextEditingController(
      text: authState.user?.displayName ?? '',
    );

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Edit Profile'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Name cannot be empty')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await context.read<AuthCubit>().updateDisplayName(newName);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showChangePasswordDialog(
    BuildContext context,
    AuthState authState,
  ) {
    final user = authState.user;
    if (user?.signInProvider == SignInProvider.google) {
      // Google users don't have a password on the Firebase side — send
      // them through the reset-password flow instead of asking for
      // credentials we can never verify.
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Reset Password'),
              content: Text(
                'You signed in with Google, so this account has no password '
                'set on our side. We will send a reset link to '
                '${user?.email ?? 'your email'}.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await context.read<AuthCubit>().resetPassword(
                        user?.email ?? '',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Reset email sent — check your inbox'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Send Reset Email'),
                ),
              ],
            ),
      );
      return;
    }

    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (newController.text != confirmController.text) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Passwords do not match')),
                    );
                    return;
                  }
                  if (newController.text.length < 6) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Password must be at least 6 characters'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await context.read<AuthCubit>().changePassword(
                      currentPassword: currentController.text,
                      newPassword: newController.text,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Password updated!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// _ActiveSubscriptionCard — shown to Premium / Admin users
// ───────────────────────────────────────────────────────────────────────────
class _ActiveSubscriptionCard extends StatelessWidget {
  const _ActiveSubscriptionCard({
    required this.authState,
    required this.premiumState,
  });
  final AuthState authState;
  final PremiumState premiumState;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final successColor = context.semanticColors.success;
    final user = authState.user;

    final planName = _planDisplayName(premiumState.selectedPlanId);
    final isLifetime = premiumState.selectedPlanId == PlanId.lifetime;
    final trialUntil = premiumState.trialActiveUntil;
    final memberSince = user?.createdAt;

    // Format: Aug 15, 2026 — no intl dependency needed.
    String fmtDate(DateTime d) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    }

    // Status line: trial info or plain 'Active'
    String statusLabel;
    if (trialUntil != null && trialUntil.isAfter(DateTime.now())) {
      statusLabel = 'Trial ends ${fmtDate(trialUntil)}';
    } else if (isLifetime) {
      statusLabel = 'Lifetime access — never expires';
    } else {
      statusLabel = 'Active';
    }

    return Container(
      decoration: BoxDecoration(
        // Subtle premium gradient background
        gradient: LinearGradient(
          colors: [
            successColor.withValues(alpha: 0.08),
            successColor.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.mdBorder,
        border: Border.all(color: successColor.withValues(alpha: 0.3)),
        boxShadow: AppShadows.lowFor(Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: icon + plan name + Active badge ───────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: successColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.smBorder,
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: successColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planName,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusLabel,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(
                          color: successColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Active badge
                Container(
                  padding: AppInsets.tag,
                  decoration: BoxDecoration(
                    color: successColor.withValues(alpha: 0.12),
                    borderRadius: AppRadius.smBorder,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIconsFill.checkCircle,
                        size: 13,
                        color: successColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Active',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(
                          color: successColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              color: successColor.withValues(alpha: 0.15),
            ),
          ),

          // ── Feature bullets ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: const [
                _FeatureBullet(
                  icon: PhosphorIconsRegular.speakerHigh,
                  label: 'Full audio guides in 7 languages',
                ),
                SizedBox(height: 6),
                _FeatureBullet(
                  icon: PhosphorIconsRegular.infinity,
                  label: 'Unlimited audio replay',
                ),
                SizedBox(height: 6),
                _FeatureBullet(
                  icon: PhosphorIconsRegular.mapPin,
                  label: 'All 45+ heritage sites unlocked',
                ),
              ],
            ),
          ),

          // ── Member since ──────────────────────────────────────────────
          if (memberSince != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.calendarBlank,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Member since ${fmtDate(memberSince)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Manage + Restore actions ──────────────────────────────────
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showManageDialog(context),
                    icon: const Icon(
                      PhosphorIconsRegular.arrowsCounterClockwise,
                      size: 16,
                    ),
                    label: const Text('Manage'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.primary,
                      side: BorderSide(
                        color: scheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _restorePurchases(context),
                    icon: const Icon(
                      PhosphorIconsRegular.receipt,
                      size: 16,
                    ),
                    label: const Text('Restore'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      side: BorderSide(
                        color: scheme.outline.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showManageDialog(BuildContext context) {
    final planName = _planDisplayName(premiumState.selectedPlanId);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            icon: const Icon(Icons.workspace_premium_rounded),
            title: const Text('Manage Subscription'),
            content: Text(
              'You are on the $planName plan.\n\n'
              'To cancel or modify your subscription, visit the app store '
              'subscription manager on your device:\n\n'
              '• Android: Play Store → Subscriptions\n'
              '• iOS: App Store → Account → Subscriptions',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _restorePurchases(BuildContext context) {
    context.read<PremiumCubit>().restore();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Restoring purchases…'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UpgradePromptCard — shown to Free users
// ─────────────────────────────────────────────────────────────────────────────
class _UpgradePromptCard extends StatelessWidget {
  const _UpgradePromptCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.4),
        ),
        boxShadow: AppShadows.lowFor(Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smBorder,
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: scheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Free Plan',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Upgrade to unlock everything',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Feature comparison ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              children: [
                _CompareRow(
                  label: 'Audio guides',
                  freeValue: '30 sec preview',
                  premiumValue: 'Full unlimited',
                ),
                const SizedBox(height: 8),
                _CompareRow(
                  label: 'Languages',
                  freeValue: '2 (EN + SW)',
                  premiumValue: 'All 7 languages',
                ),
                const SizedBox(height: 8),
                _CompareRow(
                  label: 'Replay',
                  freeValue: 'Once per site',
                  premiumValue: 'Infinite loop',
                ),
                const SizedBox(height: 8),
                _CompareRow(
                  label: 'Offline maps',
                  freeValue: '—',
                  premiumValue: 'Coming soon',
                  premiumValueColor: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),

          // ── CTA ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => UpgradeNavigator.open(context),
                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                label: const Text('Upgrade Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable pieces
// ─────────────────────────────────────────────────────────────────────────────
class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final successColor = context.semanticColors.success;
    return Row(
      children: [
        Icon(icon, size: 16, color: successColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.freeValue,
    required this.premiumValue,
    this.premiumValueColor,
  });
  final String label;
  final String freeValue;
  final String premiumValue;
  final Color? premiumValueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final successColor =
        premiumValueColor ?? context.semanticColors.success;

    return Row(
      children: [
        // Feature name
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        // Free value
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Icon(
                PhosphorIconsRegular.x,
                size: 11,
                color: scheme.outline,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  freeValue,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: scheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Premium value
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Icon(
                PhosphorIconsFill.checkCircle,
                size: 11,
                color: successColor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  premiumValue,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout helpers (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle:
          subtitle != null
              ? Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
              : null,
      trailing: const Icon(PhosphorIconsRegular.caretRight),
      onTap: onTap,
    );
  }
}
