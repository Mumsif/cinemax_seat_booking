import 'package:flutter/material.dart';

/// Custom painter that renders a curved cinema screen with a radial glow
/// effect beneath it, mimicking a real cinema screen.
class CinemaScreenPainter extends CustomPainter {
  final double glowIntensity;

  CinemaScreenPainter({this.glowIntensity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Glow gradient beneath the screen curve ──
    final glowRect = Rect.fromLTWH(w * 0.05, h * 0.15, w * 0.9, h * 0.85);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.6),
        radius: 1.2,
        colors: [
          const Color(0xFF4A9FFF).withValues(alpha: 0.12 * glowIntensity),
          const Color(0xFF4A9FFF).withValues(alpha: 0.06 * glowIntensity),
          const Color(0xFF4A9FFF).withValues(alpha: 0.02 * glowIntensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      ).createShader(glowRect);
    canvas.drawRect(glowRect, glowPaint);

    // ── Cinema screen curve ──
    final screenPath = Path();
    screenPath.moveTo(w * 0.08, h * 0.55);
    screenPath.quadraticBezierTo(w * 0.5, h * 0.05, w * 0.92, h * 0.55);

    // Outer glow stroke
    final outerGlowPaint = Paint()
      ..color = const Color(0xFF4A9FFF).withValues(alpha: 0.15 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(screenPath, outerGlowPaint);

    // Mid glow stroke
    final midGlowPaint = Paint()
      ..color = const Color(0xFF6AB4FF).withValues(alpha: 0.25 * glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(screenPath, midGlowPaint);

    // Main screen line
    final screenPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.05 * glowIntensity),
          Colors.white.withValues(alpha: 0.6 * glowIntensity),
          Colors.white.withValues(alpha: 0.8 * glowIntensity),
          Colors.white.withValues(alpha: 0.6 * glowIntensity),
          Colors.white.withValues(alpha: 0.05 * glowIntensity),
        ],
        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(screenPath, screenPaint);
  }

  @override
  bool shouldRepaint(CinemaScreenPainter oldDelegate) =>
      oldDelegate.glowIntensity != glowIntensity;
}
