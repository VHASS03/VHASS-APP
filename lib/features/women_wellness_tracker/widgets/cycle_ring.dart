import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/wellness_theme.dart';
import '../constants/wellness_constants.dart';

/// Animated circular progress ring showing current cycle day and phase.
class CycleRing extends StatefulWidget {
  final int currentDay;
  final int cycleLength;
  final CyclePhase phase;
  final int daysUntilNextPeriod;

  const CycleRing({
    super.key,
    required this.currentDay,
    required this.cycleLength,
    required this.phase,
    required this.daysUntilNextPeriod,
  });

  @override
  State<CycleRing> createState() => _CycleRingState();
}

class _CycleRingState extends State<CycleRing> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _setupAnimation();
    _controller.forward();
  }

  void _setupAnimation() {
    final target = widget.cycleLength > 0
        ? (widget.currentDay / widget.cycleLength).clamp(0.0, 1.0)
        : 0.0;
    _progressAnimation = Tween<double>(begin: 0, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(CycleRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentDay != widget.currentDay || oldWidget.cycleLength != widget.cycleLength) {
      _controller.reset();
      _setupAnimation();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _phaseColor {
    switch (widget.phase) {
      case CyclePhase.menstrual:
        return WellnessTheme.menstrual;
      case CyclePhase.follicular:
        return WellnessTheme.follicular;
      case CyclePhase.ovulation:
        return WellnessTheme.ovulationDay;
      case CyclePhase.luteal:
        return WellnessTheme.luteal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return SizedBox(
          width: 200,
          height: 200,
          child: CustomPaint(
            painter: _RingPainter(
              progress: _progressAnimation.value,
              color: _phaseColor,
              backgroundColor: _phaseColor.withOpacity(0.15),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Day ${widget.currentDay}',
                    style: WellnessTheme.bigNumber.copyWith(
                      color: _phaseColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phaseLabels[widget.phase] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _phaseColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.daysUntilNextPeriod > 0
                        ? '${widget.daysUntilNextPeriod} days to period'
                        : 'Period expected',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 10.0;

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
