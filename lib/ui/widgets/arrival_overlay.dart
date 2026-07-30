import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_semantic_colors.dart';
import '../../data/models/site_model.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_durations.dart';

class ArrivalOverlay extends StatefulWidget {

  const ArrivalOverlay({
    super.key,
    required this.site,
    required this.uiLanguage,
    required this.onPlayAudio,
    required this.onClose,
  });
  final SiteModel site;
  final String uiLanguage;
  final VoidCallback onPlayAudio;
  final VoidCallback onClose;

  @override
  State<ArrivalOverlay> createState() => _ArrivalOverlayState();
}

class _ArrivalOverlayState extends State<ArrivalOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: AppDurations.pulse,
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Scrim background for the arrival overlay — fixed-content colour
      // sits over the navigation map so the foreground stays legible.
      color: context.semanticColors.imageScrim,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: widget.onClose,
                icon: Icon(
                  Icons.close,
                  // Close icon over the scrim/map — fixed-content white.
                  color: context.semanticColors.onImage,
                  size: 28,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.sheetBorderSmBorder,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: AppRadius.sheetBorderSmBorder,
                        child: CachedNetworkImage(
                          imageUrl: widget.site.getTransformedImageUrl(
                            transformation: 'w_400,c_fill,q_auto,f_auto',
                          ),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Theme.of(context).colorScheme.surfaceContainer,
                            child: Icon(
                              Icons.image,
                              color: Theme.of(context).colorScheme.outline,
                              size: 48,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Theme.of(context).colorScheme.surfaceContainer,
                            child: Icon(
                              Icons.image_not_supported,
                              color: Theme.of(context).colorScheme.outline,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'You have arrived at',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            // Subtitle over the scrim — onImageMuted.
                            color: context.semanticColors.onImageMuted,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.site.getName(widget.uiLanguage),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: context.semanticColors.onImage,
                          ),
                    ),
                    const SizedBox(height: 40),
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: GestureDetector(
                        onTap: widget.onPlayAudio,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary,
                            borderRadius: AppRadius.heroGreetingBorder,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap to start audio guide',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            // Hint over scrim — onImageMuted.
                            color: context.semanticColors.onImageMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
