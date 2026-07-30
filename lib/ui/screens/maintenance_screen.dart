import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_radius.dart';

import '../../blocs/localization/localization_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_semantic_colors.dart';

/// Dead-end screen shown to non-admin users while an admin has flipped
/// the maintenance-mode toggle on. The screen is intentionally minimal —
/// no navigation, no buttons, no API calls. Admins can return to the
/// admin shell via the back gesture and disable maintenance from there.
///
/// ## Routing
///
/// Rendered by `SplashScreen` when `RuntimeConfigService.instance
/// .maintenanceMode` is true and the authenticated user is not an admin.
/// Also rendered by `AdminShell` as a safety net for non-admin deep links
/// that bypass the splash.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationCubit>().state;
    final theme = Theme.of(context);

    return Scaffold(
      // Match the surrounding scaffold background so the screen feels
      // like a part of the app rather than a hard modal — admins testing
      // the toggle will appreciate the visual continuity.
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tinted illustration. Using a Container with a coloured
                // background instead of an Icon alone because a single
                // Icon looks underweighted on tablet viewports.
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.build_circle_outlined,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  loc.translations['maintenance_title'] ??
                      "We're updating the guide",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  loc.translations['maintenance_subtitle'] ??
                      'Stone Town Guide is temporarily down for maintenance. Please check back shortly.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Subtle status pill — keeps the layout from feeling
                // empty without looking like a clickable action.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.semanticColors.warning.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: AppRadius.fullBorder,
                  ),
                  child: Text(
                    loc.translations['maintenance_back_shortly'] ??
                        'Back shortly',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.warning,
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
