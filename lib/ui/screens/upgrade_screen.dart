import 'package:flutter/material.dart';
import 'upgrade_content.dart';

/// Settings → "Upgrade to Premium". Reachable when the user is free-tier.
class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: const SafeArea(child: UpgradeContent(mode: UpgradeMode.settings)),
    );
  }
}
