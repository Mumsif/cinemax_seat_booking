import 'package:flutter/material.dart';

/// A single cinema seat widget with spring-like tap animation.
/// Renders a shaped seat (rounded rectangle with a "backrest" top bar)
/// and animates scale on selection with a spring bounce effect.
class AnimatedSeatWidget extends StatefulWidget {
  final int seatState; // 0=aisle, 1=available, 2=booked, 3=selected, 4=blocked
  final VoidCallback onTap;
  final int rowIndex;
  final int colIndex;
  final Duration entranceDelay;

  const AnimatedSeatWidget({
    super.key,
    required this.seatState,
    required this.onTap,
    required this.rowIndex,
    required this.colIndex,
    this.entranceDelay = Duration.zero,
  });

  @override
  State<AnimatedSeatWidget> createState() => _AnimatedSeatWidgetState();
}

class _AnimatedSeatWidgetState extends State<AnimatedSeatWidget>
    with TickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnim;
  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  // Seat colors
  static const _availableColor = Color(0xFF1E2535);
  static const _bookedColor = Color(0xFFD4AF37);
  static const _selectedColor = Color(0xFFE50914);
  static const _blockedColor = Color(0xFF3A1015);

  // Highlight / border colors
  static const _availableBorder = Color(0xFF2A3548);
  static const _bookedBorder = Color(0xFFB8941E);
  static const _selectedBorder = Color(0xFFFF2D3A);
  static const _blockedBorder = Color(0xFF4A1520);

  @override
  void initState() {
    super.initState();

    // ── Spring-like tap animation ──
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.88), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.08), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeOut));

    // ── Staggered entrance animation ──
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _entranceFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    // Start entrance with stagger delay
    Future.delayed(widget.entranceDelay, () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void didUpdateWidget(AnimatedSeatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger spring bounce when seat state changes (selected/deselected)
    if (oldWidget.seatState != widget.seatState &&
        (widget.seatState == 3 || oldWidget.seatState == 3)) {
      _tapController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _tapController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Color _getSeatColor() {
    switch (widget.seatState) {
      case 0:
        return Colors.transparent;
      case 1:
        return _availableColor;
      case 2:
        return _bookedColor;
      case 3:
        return _selectedColor;
      case 4:
        return _blockedColor;
      default:
        return Colors.transparent;
    }
  }

  Color _getBorderColor() {
    switch (widget.seatState) {
      case 1:
        return _availableBorder;
      case 2:
        return _bookedBorder;
      case 3:
        return _selectedBorder;
      case 4:
        return _blockedBorder;
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seatState == 0) {
      return const SizedBox(width: 26, height: 28);
    }

    return FadeTransition(
      opacity: _entranceFade,
      child: SlideTransition(
        position: _entranceSlide,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 26,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: CustomPaint(
                painter: _SeatPainter(
                  color: _getSeatColor(),
                  borderColor: _getBorderColor(),
                  isSelected: widget.seatState == 3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter to render a cinema seat shape:
///  - A thin backrest bar at the top
///  - A rounded rectangular seat body below
class _SeatPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final bool isSelected;

  _SeatPainter({
    required this.color,
    required this.borderColor,
    this.isSelected = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = 4.0;

    // Backrest
    final backrestRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.1, 0, w * 0.8, h * 0.22),
      topLeft: Radius.circular(r),
      topRight: Radius.circular(r),
    );
    canvas.drawRRect(backrestRect, Paint()..color = borderColor);

    // Seat body
    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, h * 0.25, w, h * 0.72),
      topLeft: Radius.circular(r),
      topRight: Radius.circular(r),
      bottomLeft: Radius.circular(r + 1),
      bottomRight: Radius.circular(r + 1),
    );

    // Fill
    canvas.drawRRect(bodyRect, Paint()..color = color);

    // Border
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Selected glow
    if (isSelected) {
      canvas.drawRRect(
        bodyRect.inflate(1.5),
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(_SeatPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.isSelected != isSelected;
}
