import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../core/constants/app_constants.dart';

class RatingStars extends StatelessWidget {

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.showValue = true,
  });
  final double rating;
  final double size;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final starValue = index + 1;
          IconData icon;

          if (rating >= starValue) {
            icon = Icons.star;
          } else if (rating >= starValue - 0.5) {
            icon = Icons.star_half;
          } else {
            icon = Icons.star_border;
          }

          return Icon(
            icon,
            size: size,
            color: context.semanticColors.rating,
          );
        }),
        if (showValue) ...[
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: size * 0.875,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
          ),
        ],
      ],
    );
  }
}

class RatingBadge extends StatelessWidget {

  const RatingBadge({
    super.key,
    required this.rating,
    this.label,
  });
  final double rating;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppInsets.pillRow,
      decoration: BoxDecoration(
        // RatingBadge sits over a hero image — fixed-content scrim so
        // the star + number stay legible on any photograph.
        color: context.semanticColors.imageScrim,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star,
            size: 14,
            color: context.semanticColors.rating,
          ),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.semanticColors.onImage,
                ),
          ),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.semanticColors.onImageMuted,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
