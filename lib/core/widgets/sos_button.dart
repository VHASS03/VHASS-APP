import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../colors.dart';

class SOSButton extends StatefulWidget {
  final VoidCallback onActivate;
  const SOSButton({super.key, required this.onActivate});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // The ripples repeat indefinitely
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onActivate,
      child: CustomPaint(
        painter: RipplePainter(_controller),
        child: Container(
          width: 200,
          height: 200,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.emergency,
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.shield, size: 48, color: Colors.white),
              SizedBox(height: 12),
              Text(
                'SOS',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 4),
              Text('HOLD FOR HELP', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class RipplePainter extends CustomPainter {
  final Animation<double> animation;
  RipplePainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTRB(0, 0, size.width, size.height);
    for (int wave = 3; wave >= 0; wave--) {
      _drawCircle(canvas, rect, wave + animation.value);
    }
  }

  void _drawCircle(Canvas canvas, Rect rect, double value) {
    // Opacity fades out as the circle gets larger
    double opacity = (1.0 - (value / 4.0)).clamp(0.0, 1.0);
    // Circle grows from 100% to 400% size
    double radius = (rect.width / 2) * (1 + value * 0.5);

    final Paint paint = Paint()
      ..color = AppColors.emergency.withOpacity(opacity * 0.5); // Subtle red ripples

    canvas.drawCircle(rect.center, radius, paint);
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) => true;
}