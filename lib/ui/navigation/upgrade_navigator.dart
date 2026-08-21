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
/// the success dialog. Most callers leave this null and rely on the
/// default behaviour in [UpgradeContent._showSuccessDialog], which
/// automatically pops every route in the upgrade-purchase stack
/// (UpgradeScreen + PaymentSheet) and returns the user to the screen
/// that opened the paywall. The first-login offer still passes its
/// own `pushAndRemoveUntil(HomeScreen)` to also clear the offer
/// screen itself.
class UpgradeNavigator {
  const UpgradeNavigator._();

  /// Stable route name so the success dialog can walk back through
  /// the upgrade-purchase stack regardless of which screen opened it.
  /// See [UpgradeContent._showSuccessDialog].
  static const String routeName = '/upgrade-screen';

  static Future<void> open(
    BuildContext context, {
    VoidCallback? onSuccessDismiss,
  }) {
    final cubit = context.read<PremiumCubit>();
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: UpgradeNavigator.routeName),
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: UpgradeScreen(onSuccessDismiss: onSuccessDismiss),
        ),
      ),
    );
  }
}
