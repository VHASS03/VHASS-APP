import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../colors.dart';

class SOSButton extends StatefulWidget {
  final VoidCallback onActivate;
  const SOSButton({super.key, required this.onActivate});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton>
    with TickerProviderStateMixin {
  /// Controls the 3-second fill ring
  late AnimationController _holdController;

  /// Controls the looping pulse ripples while pressing
  late AnimationController _pulseController;

  /// Controls a subtle scale bounce on press
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  bool _isPressed = false;
  bool _activated = false;

  @override
  void initState() {
    super.initState();

    // 3 seconds to fill the ring
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_activated) {
          _activated = true;
          // Haptic feedback on activation
          HapticFeedback.heavyImpact();
          widget.onActivate();
        }
      });

    // Looping pulse for ripple waves
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Scale spring effect
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _holdController.dispose();
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onPressStart() {
    setState(() {
      _isPressed = true;
      _activated = false;
    });
    HapticFeedback.lightImpact();
    _holdController.forward(from: 0);
    _pulseController.repeat();
    _scaleController.forward();
  }

  void _onPressEnd() {
    if (_activated) return; // Already fired
    setState(() => _isPressed = false);
    _holdController.stop();
    _holdController.reset();
    _pulseController.stop();
    _pulseController.reset();
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _onPressStart(),
      onTapUp: (_) => _onPressEnd(),
      onTapCancel: _onPressEnd,
      child: AnimatedBuilder(
        animation: Listenable.merge([_holdController, _scaleAnim]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(
                painter: _SOSRingPainter(
                  progress: _holdController.value,
                  pulseAnimation: _pulseController,
                  isActive: _isPressed,
                ),
                child: child,
              ),
            ),
          );
        },
        child: Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEE5A6F),
                  AppColors.emergency,
                  Color(0xFFCC3248),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emergency.withOpacity(0.45),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppColors.blush.withOpacity(0.25),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_rounded, size: 44, color: Colors.white),
                const SizedBox(height: 10),
                const Text(
                  'SOS',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    color: _isPressed
                        ? Colors.white
                        : Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                  child: Text(
                    _isPressed ? 'KEEP HOLDING…' : 'HOLD FOR HELP',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Custom Painter: ring progress + ripple waves ----------

class _SOSRingPainter extends CustomPainter {
  final double progress; // 0..1 over 3 seconds
  final Animation<double> pulseAnimation;
  final bool isActive;

  _SOSRingPainter({
    required this.progress,
    required this.pulseAnimation,
    required this.isActive,
  }) : super(repaint: pulseAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    // --- Ripple waves (while pressed) ---
    if (isActive) {
      for (int i = 2; i >= 0; i--) {
        final waveValue = (pulseAnimation.value + i * 0.33) % 1.0;
        final waveRadius = radius + waveValue * 40;
        final opacity = (1.0 - waveValue).clamp(0.0, 1.0) * 0.18;
        canvas.drawCircle(
          center,
          waveRadius,
          Paint()..color = AppColors.blush.withOpacity(opacity),
        );
      }
    }

    // --- Background track ring ---
    final trackPaint = Paint()
      ..color = AppColors.blush.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius - 4, trackPaint);

    // --- Progress arc (fills over 3 seconds) ---
    if (progress > 0) {
      final arcRect = Rect.fromCircle(center: center, radius: radius - 4);
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + math.pi * 2 * progress,
          colors: const [
            AppColors.blush,
            AppColors.emergency,
          ],
          stops: const [0.0, 1.0],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(arcRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SOSRingPainter old) => true;
}
