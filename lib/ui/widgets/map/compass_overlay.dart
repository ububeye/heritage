import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';

/// Round compass widget rendered on top of the map while the navigation
/// screen is in heading-locked follow mode.
///
/// The dial rotates so that the red "N" needle always points to true north
/// (or relative to the map when the map itself is rotated). The current
/// heading is shown underneath as a label.
///
/// The widget is only visible while the parent decides to show it — it is
/// transparent in the layout when `headingDeg == null`, so callers don't
/// have to special-case absence in the layout.
class CompassOverlay extends StatelessWidget {
  const CompassOverlay({
    super.key,
    required this.headingDeg,
    this.size = 44,
    this.background,
    this.needleColor,
    this.borderColor,
  });

  /// Current compass heading in degrees (0 = north, 90 = east). When `null`
  /// the overlay renders an empty placeholder so it doesn't cause layout
  /// flicker.
  final double? headingDeg;

  /// Outer diameter of the dial.
  final double size;

  /// Optional override for the dial background. Defaults to a surface-tinted
  /// circular background.
  final Color? background;

  /// Optional override for the north-pointing needle. Defaults to error color.
  final Color? needleColor;

  /// Optional override for the dial border. Defaults to outlineVariant.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    if (headingDeg == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final bg = background ?? scheme.surface;
    final needle = needleColor ?? scheme.error;
    final border = borderColor ?? scheme.outlineVariant;

    final deg = headingDeg!.clamp(0.0, 360.0);
    final degrees = deg.toStringAsFixed(0).padLeft(3, '0');

    return Material(
      color: bg,
      shape: CircleBorder(
        side: BorderSide(color: border, width: 1),
      ),
      elevation: 4,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Rotating needle.
            Transform.rotate(
              angle: deg * math.pi / 180.0,
              child: CustomPaint(
                size: Size(size * 0.78, size * 0.78),
                painter: _CompassNeedlePainter(
                  needleColor: needle,
                ),
              ),
            ),
            // Heading label sits on top.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: AppRadius.xsBorder,
              ),
              child: Text(
                '$degrees°',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompassNeedlePainter extends CustomPainter {
  _CompassNeedlePainter({required this.needleColor});
  final Color needleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = math.min(w, h) / 2 - 1.5;

    final ring = Paint()
      ..color = needleColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, ring);

    // North-pointing needle (red, points up).
    final northPaint = Paint()
      ..color = needleColor
      ..style = PaintingStyle.fill;
    final northPath = Path()
      ..moveTo(cx, cy - r + 1)
      ..lineTo(cx - r * 0.18, cy)
      ..lineTo(cx + r * 0.18, cy)
      ..close();
    canvas.drawPath(northPath, northPaint);

    // South-pointing needle (subtle, theme outline).
    final southPaint = Paint()
      ..color = needleColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    final southPath = Path()
      ..moveTo(cx, cy + r - 1)
      ..lineTo(cx - r * 0.18, cy)
      ..lineTo(cx + r * 0.18, cy)
      ..close();
    canvas.drawPath(southPath, southPaint);
  }

  @override
  bool shouldRepaint(_CompassNeedlePainter oldDelegate) =>
      oldDelegate.needleColor != needleColor;
}
