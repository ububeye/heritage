import 'package:flutter/material.dart';

/// Blue-and-white dot rendered on the map at the user's current GPS
/// position. Heading is rendered as a small wedge in front of the dot when
/// [headingDeg] is non-null.
///
/// This widget is intentionally headless — it consumes no `flutter_map`
/// internals and renders as a regular [Widget]. Wrap in `Marker(...)` (from
/// `flutter_map`) at the call site.
class UserMarker extends StatelessWidget {
  const UserMarker({
    super.key,
    required this.headingDeg,
    this.color = const Color(0xFF1E88E5),
    this.size = 18,
  });

  /// Current heading in degrees (0 = north). When non-null a wedge is
  /// rendered pointing in that direction.
  final double? headingDeg;

  /// Dot fill colour.
  final Color color;

  /// Dot diameter in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final haloColor = color.withValues(alpha: 0.18);
    final showHeading = headingDeg != null;

    return SizedBox(
      width: size * 2.4,
      height: size * 2.4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 2.0,
            height: size * 2.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: haloColor,
            ),
          ),
          if (showHeading)
            Transform.rotate(
              angle: headingDeg! * 3.14159265 / 180.0,
              child: CustomPaint(
                size: Size(size * 2.0, size * 2.0),
                painter: _HeadingWedgePainter(color: color),
              ),
            ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadingWedgePainter extends CustomPainter {
  _HeadingWedgePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(cx, cy - h * 0.42)
      ..lineTo(cx - w * 0.18, cy + h * 0.18)
      ..lineTo(cx + w * 0.18, cy + h * 0.18)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HeadingWedgePainter oldDelegate) =>
      oldDelegate.color != color;
}
