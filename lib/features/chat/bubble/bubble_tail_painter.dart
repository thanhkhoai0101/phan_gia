import 'package:flutter/material.dart';

class BubbleTailPainter extends CustomPainter {
  final Color color;

  BubbleTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    final path = Path();

    path.moveTo(0, 0);
    path.quadraticBezierTo(
      size.width,
      size.height / 2,
      0,
      size.height,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
