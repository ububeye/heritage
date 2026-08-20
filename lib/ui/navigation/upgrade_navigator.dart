import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/premium/premium_cubit.dart';
import '../screens/upgrade_screen.dart';

/// Centralized helper for opening the paywall from anywhere in the app.
///
/// Routes through [UpgradeScreen] (the Settings-style wrapper around
/// [UpgradeContent]) and re-provides the existing [PremiumCubit] on the
/// pushed route — new [MaterialPageRoute] subtrees don't inherit bloc
/// providers from the parent navigator, so the cubit must be passed in.
///
/// [onSuccessDismiss] fires after the user taps "Start Exploring" in
/// the success dialog. Most callers pass a single [Navigator.pop] to
/// return the user to whichever screen launched the paywall; the
/// first-login offer passes a `pushAndRemoveUntil(HomeScreen)` so the
/// offer screen itself is dismissed (and bypasses this helper entirely
/// to avoid the Settings-style AppBar).
class UpgradeNavigator {
  const UpgradeNavigator._();

  static Future<void> open(
    BuildContext context, {
    VoidCallback? onSuccessDismiss,
  }) {
    final cubit = context.read<PremiumCubit>();
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: UpgradeScreen(onSuccessDismiss: onSuccessDismiss),
        ),
      ),
    );
  }
}
