import '../../core/theme/app_radius.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

class UpgradeBanner extends StatelessWidget {

  const UpgradeBanner({
    super.key,
    required this.onUpgrade,
    this.message,
  });
  final VoidCallback onUpgrade;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUpgrade,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onError.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.lock,
                color: Theme.of(context).colorScheme.onError,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upgrade for Full Audio',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textOnPrimary,
                        ),
                  ),
                  if (message != null)
                    Text(
                      message!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                          ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Theme.of(context).colorScheme.onError,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
