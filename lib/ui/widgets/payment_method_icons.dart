import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Recognizable brand-icon widgets for the payment form.
///
/// Each icon is drawn with `CustomPaint` — no external SVG dependencies.
/// The icons are stylised but clearly recognisable for the five major
/// payment brands: Visa, Mastercard, Amex, PayPal, M-Pesa, Google Pay.
class PaymentMethodIcons {
  PaymentMethodIcons._();

  static Widget visa({double size = 42}) =>
      SizedBox(width: size * 1.6, height: size, child: CustomPaint(painter: _VisaPainter()));

  static Widget mastercard({double size = 42}) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _MastercardPainter()));

  static Widget amex({double size = 42}) =>
      SizedBox(width: size * 1.6, height: size, child: CustomPaint(painter: _AmexPainter()));

  static Widget paypal({double size = 42}) =>
      SizedBox(width: size * 1.4, height: size, child: CustomPaint(painter: _PaypalPainter()));

  static Widget mpesa({double size = 42}) =>
      SizedBox(width: size * 1.6, height: size, child: CustomPaint(painter: _MpesaPainter()));

  static Widget googlePay({double size = 42}) =>
      SizedBox(width: size * 1.8, height: size, child: CustomPaint(painter: _GooglePayPainter()));
}

// ── Visa ─────────────────────────────────────────────────────────────────────
class _VisaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Card background
    _drawCard(canvas, size, const Color(0xFF1A1F71));
    // "VISA" text
    final tp = _tp(
      'VISA',
      color: Colors.white,
      fontSize: size.height * 0.38,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w900,
    );
    tp.paint(
      canvas,
      Offset(
        (size.width - tp.width) / 2,
        (size.height - tp.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Mastercard ────────────────────────────────────────────────────────────────
class _MastercardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawCard(canvas, size, const Color(0xFF252525));
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.height * 0.32;
    final offset = r * 0.55;

    // Red circle (left)
    canvas.drawCircle(
      Offset(cx - offset, cy),
      r,
      Paint()..color = const Color(0xFFEB001B),
    );
    // Orange circle (right)
    canvas.drawCircle(
      Offset(cx + offset, cy),
      r,
      Paint()..color = const Color(0xFFF79E1B),
    );
    // Blend overlap (drawn on top)
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.62,
      Paint()
        ..color = const Color(0xFFFF5F00)
        ..blendMode = BlendMode.srcOver,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── American Express ──────────────────────────────────────────────────────────
class _AmexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawCard(canvas, size, const Color(0xFF2E77BC));
    final tp = _tp(
      'AMEX',
      color: Colors.white,
      fontSize: size.height * 0.30,
      fontWeight: FontWeight.w900,
    );
    tp.paint(
      canvas,
      Offset(
        (size.width - tp.width) / 2,
        (size.height - tp.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── PayPal ────────────────────────────────────────────────────────────────────
class _PaypalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawCard(canvas, size, const Color(0xFF003087));
    // "Pay" in white, "Pal" in light-blue
    final pay = _tp(
      'Pay',
      color: Colors.white,
      fontSize: size.height * 0.32,
      fontWeight: FontWeight.w800,
    );
    final pal = _tp(
      'Pal',
      color: const Color(0xFF009CDE),
      fontSize: size.height * 0.32,
      fontWeight: FontWeight.w800,
    );
    final totalW = pay.width + pal.width;
    final x0 = (size.width - totalW) / 2;
    final y = (size.height - pay.height) / 2;
    pay.paint(canvas, Offset(x0, y));
    pal.paint(canvas, Offset(x0 + pay.width, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── M-Pesa ────────────────────────────────────────────────────────────────────
class _MpesaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    _drawCard(canvas, size, const Color(0xFF00A650));
    final tp = _tp(
      'M-PESA',
      color: Colors.white,
      fontSize: size.height * 0.28,
      fontWeight: FontWeight.w900,
    );
    tp.paint(
      canvas,
      Offset(
        (size.width - tp.width) / 2,
        (size.height - tp.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Google Pay ────────────────────────────────────────────────────────────────
class _GooglePayPainter extends CustomPainter {
  static const _gColors = [
    Color(0xFF4285F4), // blue
    Color(0xFFEA4335), // red
    Color(0xFFFBBC05), // yellow
    Color(0xFF34A853), // green
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _drawCard(canvas, size, Colors.white, borderColor: const Color(0xFFDDDDDD));

    // G letter — four coloured arcs
    final cx = size.width * 0.28;
    final cy = size.height / 2;
    final r = size.height * 0.28;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final strokeW = r * 0.38;

    for (int i = 0; i < 4; i++) {
      final p =
          Paint()
            ..color = _gColors[i]
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, math.pi / 2 * i, math.pi / 2 - 0.08, false, p);
    }

    // Horizontal bar of the G
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - strokeW / 2, r, strokeW),
      Paint()..color = _gColors[0],
    );

    // "Pay" text
    final tp = _tp(
      'Pay',
      color: const Color(0xFF222222),
      fontSize: size.height * 0.30,
      fontWeight: FontWeight.w600,
    );
    tp.paint(
      canvas,
      Offset(cx + r + size.width * 0.06, (size.height - tp.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Shared helpers ────────────────────────────────────────────────────────────

/// Draws a rounded-rectangle card background.
void _drawCard(
  Canvas canvas,
  Size size,
  Color fill, {
  Color borderColor = Colors.transparent,
}) {
  final rr = RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Radius.circular(size.height * 0.15),
  );
  canvas.drawRRect(rr, Paint()..color = fill);
  if (borderColor != Colors.transparent) {
    canvas.drawRRect(
      rr,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}

/// Builds a [TextPainter] and calls [layout] on it.
TextPainter _tp(
  String text, {
  required Color color,
  required double fontSize,
  FontWeight fontWeight = FontWeight.normal,
  FontStyle fontStyle = FontStyle.normal,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: 0.5,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return tp;
}

// ── Compact icon row widget ───────────────────────────────────────────────────

/// Horizontal row of all supported payment brand icons.
/// Used at the bottom of the upgrade screen and in the payment form header.
class PaymentBrandRow extends StatelessWidget {
  const PaymentBrandRow({super.key, this.iconHeight = 28});
  final double iconHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          PaymentMethodIcons.visa(size: iconHeight),
          PaymentMethodIcons.mastercard(size: iconHeight),
          PaymentMethodIcons.amex(size: iconHeight),
          PaymentMethodIcons.paypal(size: iconHeight),
          PaymentMethodIcons.mpesa(size: iconHeight),
          PaymentMethodIcons.googlePay(size: iconHeight),
        ],
      ),
    );
  }
}
