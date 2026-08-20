import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/premium/premium_cubit.dart';
import 'home_screen.dart';
import 'upgrade_content.dart';

/// First-login value-prop screen. Replaces the original paywall with
/// a low-pressure intro that lists what premium unlocks and lets the
/// user continue to the home without seeing prices. The actual pricing
/// surface lives in [UpgradeScreen], reachable only via the persistent
/// `UpgradeBanner` on the detail screen or the Upgrade action on the
/// 30-second preview SnackBar.
///
/// The screen is gated by the login/register listeners so that users
/// who have already heard at least one audio preview (i.e. they
/// already know the audio tour exists) skip this screen entirely on
/// subsequent sign-ins.
class PremiumOfferScreen extends StatelessWidget {
  const PremiumOfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => _skip(context),
            child: Text(
              'Skip',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Text(
                'Welcome to Stone Town',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Here's what is waiting for you inside",
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 28),
              const _FeatureRow(
                icon: Icons.headphones,
                title: 'Full-length audio tours',
                subtitle:
                    'Hear every story end-to-end — not a 30-second preview.',
              ),
              const SizedBox(height: 16),
              const _FeatureRow(
                icon: Icons.translate,
                title: '7 audio languages',
                subtitle:
                    'English, Swahili, Arabic, French, German, Italian, Spanish.',
              ),
              const SizedBox(height: 16),
              const _FeatureRow(
                icon: Icons.map_outlined,
                title: 'Offline maps & GPS',
                subtitle:
                    'Walk the alleys without roaming — the full Stone Town guide in your pocket.',
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _skip(context),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Continue to the Home',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              // "See plans" — let users inspect pricing and buy from
              // the offer screen without going through Settings. We
              // route into UpgradeContent with onboarding mode so the
              // secondary copy ("Maybe later") stays consistent with
              // this screen's low-pressure framing. PremiumCubit is
              // re-provided on the pushed route because new
              // MaterialPageRoute subtrees do not inherit bloc
              // providers from the parent navigator.
              OutlinedButton(
                onPressed: () => _seePlans(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: scheme.primary,
                  side: BorderSide(color: scheme.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'See plans',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _skip(context),
                child: const Text('Maybe later'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _skip(BuildContext context) {
    context.read<PremiumCubit>().skipPremiumOffer();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _seePlans(BuildContext context) {
    final cubit = context.read<PremiumCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: UpgradeContent(
            mode: UpgradeMode.onboarding,
            // On success, collapse the entire stack back to a fresh
            // HomeScreen. Without this, the user lands back on
            // PremiumOfferScreen after dismissing the success dialog —
            // which feels like a separate paywall page rather than the
            // same app.
            onSuccessDismiss: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: scheme.primary, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
