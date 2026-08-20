import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A live map scale bar.
///
/// Renders a horizontal bar in the bottom-left corner of the map. The bar
/// is sized so it represents a "nice" round metric distance (1, 2, 5, 10,
/// 20, 50, 100, 200, 500 m / 1, 2, 5, 10 km, etc.) at the current camera
/// zoom. The bar updates whenever the camera changes — i.e. it tracks the
/// `MapController.camera` cleanly without subscribing to GPS or the
/// navigation stream.
class MapScaleBar extends StatelessWidget {
  const MapScaleBar({
    super.key,
    required this.mapController,
    this.textStyle,
    this.barColor,
    this.padding = const EdgeInsets.all(8),
    this.isImperial = false,
  });

  /// The map controller whose `camera` we read for the current zoom + centre.
  ///
  /// `MapControllerImpl` is a `ValueNotifier<MapControllerState>` under the
  /// hood, so we listen to it as a [ValueListenable] to rebuild the bar
  /// whenever the camera moves.
  final MapController mapController;

  /// Text style for the distance label. Defaults to a small white-on-dark
  /// caption so it stays readable on any basemap.
  final TextStyle? textStyle;

  /// Bar colour. Defaults to `Colors.white`.
  final Color? barColor;

  /// Edge inset from the bottom-left corner.
  final EdgeInsets padding;

  /// If true, the label is rendered in feet/miles instead of meters/km.
  final bool isImperial;

  @override
  Widget build(BuildContext context) {
    final listenable = mapController as ValueListenable<Object?>;
    return ValueListenableBuilder<Object?>(
      valueListenable: listenable,
      builder: (context, _, __) {
        final cam = mapController.camera;
        final metersPerPixel = _metersPerPixel(cam.center, cam.zoom);
        // We want a bar roughly 100 px wide. Pick the largest "nice" distance
        // <= 100 * metersPerPixel.
        final niceMeters = _niceRound(100 * metersPerPixel);
        final widthPx = niceMeters / metersPerPixel;
        final label = _labelFor(niceMeters);
        final color = barColor ?? Colors.white;
        final style = textStyle ??
            TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            );

        return Padding(
          padding: padding,
          child: SizedBox(
            width: widthPx,
            child: CustomPaint(
              painter: _ScaleBarPainter(
                color: color,
                strokeWidth: 2,
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(label, style: style, textAlign: TextAlign.center),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Equirectangular metres per pixel at the given centre latitude and zoom.
  /// 256 px is the standard tile width at zoom 0.
  static double _metersPerPixel(LatLng center, double zoom) {
    final groundResolution =
        156543.03392 * math.cos(center.latitude * math.pi / 180.0);
    return groundResolution / (256 * math.pow(2, zoom));
  }

  /// Largest "nice" round number <= [meters] drawn from the set
  /// {1, 2, 5} × 10^n for n = 0, 1, 2, 3, 4.
  static double _niceRound(double meters) {
    const bases = [1, 2, 5];
    var exponent = 0;
    var n = meters;
    while (n >= 10) {
      n /= 10;
      exponent++;
    }
    while (n < 1) {
      n *= 10;
      exponent--;
    }
    var best = bases.first.toDouble();
    for (final b in bases) {
      final candidate = b * math.pow(10, exponent).toDouble();
      if (candidate <= meters) {
        best = candidate;
      }
    }
    return best;
  }

  String _labelFor(double meters) {
    if (isImperial) {
      if (meters >= 1609.34) {
        final miles = meters / 1609.34;
        return '${miles.toStringAsFixed(miles >= 10 ? 0 : 1)} mi';
      }
      final feet = meters * 3.28084;
      return '${feet.toStringAsFixed(0)} ft';
    }
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}

class _ScaleBarPainter extends CustomPainter {
  _ScaleBarPainter({required this.color, required this.strokeWidth});
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final y = strokeWidth / 2;
    // Top bar (the scale segments).
    final half = size.width / 2;
    canvas.drawLine(Offset(0, y), Offset(half, y), paint);
    canvas.drawLine(Offset(half, y), Offset(size.width, y), paint);
    // Tick marks at the ends and midpoint.
    canvas.drawLine(Offset(0, 0), Offset(0, 6), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, 6), paint);
    canvas.drawLine(Offset(half, y - 2), Offset(half, y + 4), paint);
  }

  @override
  bool shouldRepaint(_ScaleBarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
