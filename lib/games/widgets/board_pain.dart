import 'package:flutter/material.dart';

class BoardPainter
    extends CustomPainter {
  @override
  void paint(
      Canvas canvas,
      Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1;

    double cell =
        size.width / 15;

    for (int i = 0; i < 15; i++) {
      canvas.drawLine(
        Offset(cell * i, 0),
        Offset(cell * i, size.height),
        paint,
      );

      canvas.drawLine(
        Offset(0, cell * i),
        Offset(size.width, cell * i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
      CustomPainter oldDelegate) {
    return false;
  }
}
