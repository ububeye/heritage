import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_semantic_colors.dart';

/// Non-blocking "Recalculating route…" banner shown above the maneuver card
/// while the navigation screen is mid-reroute.
///
/// Visibility is controlled by a parent-managed boolean. The banner slides
/// in/out via [AnimatedSwitcher] so the transition feels smooth even when
/// the user is mid-pan.
class OffRouteBanner extends StatelessWidget {
  const OffRouteBanner({
    super.key,
    required this.isVisible,
    this.label = 'Recalculating route…',
  });

  /// Whether the banner should currently be on-screen.
  final bool isVisible;

  /// Localized label. Defaults to a generic English string.
  final String label;

  @override
  Widget build(BuildContext context) {
    final warningFg = context.semanticColors.onWarning;
    final warningBg = context.semanticColors.warning;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: isVisible
          ? Padding(
              key: const ValueKey('off_route_banner_visible'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Material(
                color: warningBg,
                elevation: 0,
                borderRadius: AppRadius.smBorder,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(warningFg),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: warningFg,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('off_route_banner_hidden')),
    );
  }
}

/// Hook-style helper that auto-debounces a `bool` flag so an off-route
/// spike doesn't flash the banner on and off every second.
class OffRouteBannerController {
  bool _isVisible = false;
  Timer? _hideTimer;
  void Function()? _onChange;

  bool get isVisible => _isVisible;

  void bind(void Function() onChange) {
    _onChange = onChange;
  }

  void show({Duration hold = const Duration(milliseconds: 2500)}) {
    _hideTimer?.cancel();
    _isVisible = true;
    _onChange?.call();
    _hideTimer = Timer(hold, () {
      if (!_isVisible) return;
      _isVisible = false;
      _onChange?.call();
    });
  }

  void hide() {
    _hideTimer?.cancel();
    if (!_isVisible) return;
    _isVisible = false;
    _onChange?.call();
  }

  void dispose() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _onChange = null;
  }
}
