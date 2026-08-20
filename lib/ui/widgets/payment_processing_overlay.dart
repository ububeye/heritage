import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Full-screen animated overlay shown while payment is processing.
///
/// Lifecycle:
///   1. Appears with a fade-in and a subtle scale-up.
///   2. Shows a spinning arc ring with the [label] below it.
///   3. On [success], the ring morphs into a green ✓ checkmark.
///   4. On [failure], the ring morphs into a red ✗.
///   5. Auto-dismisses after 1.8 s (success) / 2.5 s (failure).
///
/// Usage:
/// ```dart
/// PaymentProcessingOverlay.show(context, label: 'Processing payment…');
/// // later:
/// PaymentProcessingOverlay.complete(context, success: true);
/// ```
class PaymentProcessingOverlay extends StatefulWidget {
  const PaymentProcessingOverlay({
    super.key,
    required this.label,
    required this.onDone,
  });

  final String label;
  final void Function(bool success) onDone;

  @override
  State<PaymentProcessingOverlay> createState() =>
      PaymentProcessingOverlayState();
}

class PaymentProcessingOverlayState extends State<PaymentProcessingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _resultCtrl;

  /// null = still spinning, true = success, false = failure
  bool? _result;
  String _label = '';

  @override
  void initState() {
    super.initState();
    _label = widget.label;

    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  /// Called by the parent once the billing result is known.
  void showResult({required bool success, required String label}) {
    if (!mounted) return;
    setState(() {
      _result = success;
      _label = label;
    });
    _spinCtrl.stop();
    _resultCtrl.forward();

    Future.delayed(
      Duration(milliseconds: success ? 1800 : 2500),
      () {
        if (mounted) widget.onDone(success);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = _result;

    final ringColor =
        r == null
            ? scheme.primary
            : (r ? const Color(0xFF22C55E) : scheme.error);

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child:
                  r == null
                      ? _SpinningRing(color: ringColor, ctrl: _spinCtrl)
                      : _ResultMark(
                          success: r,
                          controller: _resultCtrl,
                          color: ringColor,
                        ),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _label,
                key: ValueKey(_label),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (r != null) ...[
              const SizedBox(height: 10),
              Text(
                r ? 'Your languages are now unlocked ✓' : 'Please try again',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Spinning arc ring ─────────────────────────────────────────────────────────

class _SpinningRing extends StatelessWidget {
  const _SpinningRing({required this.color, required this.ctrl});
  final Color color;
  final AnimationController ctrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        return CustomPaint(
          painter: _ArcPainter(angle: ctrl.value * 2 * math.pi, color: color),
        );
      },
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.angle, required this.color});
  final double angle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeW = size.width * 0.10;
    final r = (size.width - strokeW) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    // Track ring (faint)
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW,
    );

    // Active arc
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawArc(
      rect,
      -math.pi / 2 + angle,
      math.pi * 1.3,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.angle != angle || old.color != color;
}

// ── Result mark (tick or X) ───────────────────────────────────────────────────

class _ResultMark extends StatelessWidget {
  const _ResultMark({
    required this.success,
    required this.controller,
    required this.color,
  });
  final bool success;
  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = Curves.elasticOut.transform(controller.value.clamp(0.0, 1.0));
        return Transform.scale(
          scale: t,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              success ? Icons.check_rounded : Icons.close_rounded,
              size: 52,
              color: color,
            ),
          ),
        );
      },
    );
  }
}
