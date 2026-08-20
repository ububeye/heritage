import 'package:flutter/material.dart';
import 'upgrade_content.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Settings → "Upgrade to Premium". Reachable when the user is free-tier.
class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key, this.onSuccessDismiss});

  /// Fires after the user taps "Start Exploring" in the success dialog.
  /// Most call sites pass a single [Navigator.pop] to return the user to
  /// whichever screen launched the paywall. First-login callers pass a
  /// `pushAndRemoveUntil(HomeScreen)` so the offer screen itself is
  /// dismissed (the first-login flow bypasses this widget and wires the
  /// callback into [UpgradeContent] directly).
  final VoidCallback? onSuccessDismiss;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Go Premium'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: UpgradeContent(
          mode: UpgradeMode.settings,
          onSuccessDismiss: onSuccessDismiss,
        ),
      ),
    );
  }
}
