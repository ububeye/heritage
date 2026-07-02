import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/premium/premium_cubit.dart';
import '../../blocs/premium/premium_state.dart';
import 'home_screen.dart';
import 'upgrade_content.dart';

/// First-login paywall. Thin wrapper around [UpgradeContent] with the
/// "onboarding" mode: dismisses to Home instead of popping, hides the
/// "Restore purchases" link.
class PremiumOfferScreen extends StatelessWidget {
  const PremiumOfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<PremiumCubit>().skipPremiumOffer();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                );
              }
            },
            child: Text(
              'Skip',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocListener<PremiumCubit, PremiumState>(
        listenWhen: (prev, next) =>
            prev.isPremium != next.isPremium && next.isPremium,
        listener: (context, state) {
          // Once the cubit flips to premium, the success dialog has
          // already shown via UpgradeContent. Push to Home so the user
          // lands somewhere useful instead of back on this paywall.
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        },
        child: SafeArea(
          child: UpgradeContent(
            mode: UpgradeMode.onboarding,
            onSuccessDismiss: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
          ),
        ),
      ),
    );
  }
}
