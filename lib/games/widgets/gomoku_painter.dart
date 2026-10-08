import 'dart:math';
import 'package:flutter/material.dart';

class GomokuPainter extends CustomPainter {
  final List<List<int>> board;
  final int? selectedRow;
  final int? selectedCol;
  final int? previewPiece;
  final int? lastRow;
  final int? lastCol;

  GomokuPainter({
    required this.board,
    this.selectedRow,
    this.selectedCol,
    this.previewPiece,
    this.lastRow,
    this.lastCol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const boardSize = 15;
    final side = min(size.width, size.height);
    final margin = side * 0.05;
    final step = (side - 2 * margin) / (boardSize - 1);

    // Center the square board inside the available size
    final offsetX = (size.width - side) / 2.0;
    final offsetY = (size.height - side) / 2.0;

    final boardRect = Rect.fromLTWH(offsetX, offsetY, side, side);

    // 1. Draw Outer Glowing Aura & Background (Celestial Xianxia Theme)
    final shadowPaint = Paint()
      ..color = const Color(0xFF4EE2EC).withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect.inflate(6), const Radius.circular(16)),
      shadowPaint,
    );

    // Deep Dark Cyan Board Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0F2332), // Dark Oceanic Slate
          Color(0xFF193447), // Deep Celestial Cyan
          Color(0xFF0C1B28), // Deep Shadow Blue
        ],
      ).createShader(boardRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(14)),
      bgPaint,
    );

    // 2. Draw Glowing Cyan Border Frame
    final borderPaint = Paint()
      ..color = const Color(0xFF4EE2EC).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, const Radius.circular(14)),
      borderPaint,
    );

    final innerBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect.deflate(4), const Radius.circular(10)),
      innerBorderPaint,
    );

    // 3. Draw Grid Lines (Intersection Based 15x15)
    final linePaint = Paint()
      ..color = const Color(0xFF80E9FF).withValues(alpha: 0.35)
      ..strokeWidth = 1.0;

    for (int i = 0; i < boardSize; i++) {
      // Vertical lines
      final x = offsetX + margin + i * step;
      canvas.drawLine(
        Offset(x, offsetY + margin),
        Offset(x, offsetY + side - margin),
        linePaint,
      );

      // Horizontal lines
      final y = offsetY + margin + i * step;
      canvas.drawLine(
        Offset(offsetX + margin, y),
        Offset(offsetX + side - margin, y),
        linePaint,
      );
    }

    // 4. Draw Star Points (5 Hoshi dots)
    final starPoints = [
      [3, 3], [3, 11], [11, 3], [11, 11], [7, 7]
    ];
    final starGlowPaint = Paint()
      ..color = const Color(0xFF4EE2EC).withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final starDotPaint = Paint()..color = const Color(0xFFE0F7FA);

    for (var point in starPoints) {
      final center = Offset(
        offsetX + margin + point[1] * step,
        offsetY + margin + point[0] * step,
      );
      canvas.drawCircle(center, step * 0.16, starGlowPaint);
      canvas.drawCircle(center, step * 0.09, starDotPaint);
    }

    // 5. Draw Glowing Crosshair Guide Lines if a Cell is Selected!
    if (selectedRow != null && selectedCol != null) {
      final r = selectedRow!;
      final c = selectedCol!;
      final targetX = offsetX + margin + c * step;
      final targetY = offsetY + margin + r * step;

      // Crosshair Glow
      final crosshairGlow = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.5)
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      // Vertical Guide Line
      canvas.drawLine(
        Offset(targetX, offsetY + margin),
        Offset(targetX, offsetY + side - margin),
        crosshairGlow,
      );
      // Horizontal Guide Line
      canvas.drawLine(
        Offset(offsetX + margin, targetY),
        Offset(offsetX + side - margin, targetY),
        crosshairGlow,
      );

      // Bright Core Crosshair Line
      final crosshairCore = Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..strokeWidth = 1.2;

      canvas.drawLine(
        Offset(targetX, offsetY + margin),
        Offset(targetX, offsetY + side - margin),
        crosshairCore,
      );
      canvas.drawLine(
        Offset(offsetX + margin, targetY),
        Offset(offsetX + side - margin, targetY),
        crosshairCore,
      );
    }

    // 6. Draw Placed Stones
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        final val = board[r][c];
        if (val == 0) continue;

        final center = Offset(
          offsetX + margin + c * step,
          offsetY + margin + r * step,
        );

        _drawStone(canvas, center, step * 0.44, val, opacity: 1.0);

        // Highlight last move if matches
        if (lastRow == r && lastCol == c) {
          final lastGlow = Paint()
            ..color = const Color(0xFF4EE2EC).withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          canvas.drawCircle(center, step * 0.47, lastGlow);

          final lastDot = Paint()..color = const Color(0xFF00E5FF);
          canvas.drawCircle(center, step * 0.1, lastDot);
        }
      }
    }

    // 7. Draw Preview Stone on Selected Cell
    if (selectedRow != null && selectedCol != null) {
      final r = selectedRow!;
      final c = selectedCol!;
      if (r >= 0 && r < boardSize && c >= 0 && c < boardSize && board[r][c] == 0) {
        final center = Offset(
          offsetX + margin + c * step,
          offsetY + margin + r * step,
        );

        // Glowing selection ring
        final targetRingGlow = Paint()
          ..color = const Color(0xFF00E5FF).withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(center, step * 0.47, targetRingGlow);

        final targetRing = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(center, step * 0.47, targetRing);

        // Preview Stone (translucent)
        final pPiece = previewPiece ?? 1;
        _drawStone(canvas, center, step * 0.44, pPiece, opacity: 0.75);
      }
    }
  }

  void _drawStone(Canvas canvas, Offset center, double radius, int pieceType, {required double opacity}) {
    final isBlack = pieceType == 1;

    // Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawCircle(
      Offset(center.dx + 2, center.dy + 3),
      radius,
      shadowPaint,
    );

    if (isBlack) {
      // 3D Obsidian Black Stone
      final stoneRect = Rect.fromCircle(center: center, radius: radius);
      final stonePaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 0.85,
          colors: [
            const Color(0xFF616161).withValues(alpha: opacity),
            const Color(0xFF212121).withValues(alpha: opacity),
            const Color(0xFF0A0A0A).withValues(alpha: opacity),
          ],
        ).createShader(stoneRect);

      canvas.drawCircle(center, radius, stonePaint);

      // Specular highlight arc
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(center.dx - radius * 0.2, center.dy - radius * 0.2), radius: radius * 0.6),
        3.8,
        1.5,
        false,
        highlightPaint,
      );
    } else {
      // 3D Luminous Cyan-White Pearl / Jade Stone
      final stoneRect = Rect.fromCircle(center: center, radius: radius);
      final stonePaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 0.85,
          colors: [
            Colors.white.withValues(alpha: opacity),
            const Color(0xFFE0F7FA).withValues(alpha: opacity),
            const Color(0xFF80DEEA).withValues(alpha: opacity),
            const Color(0xFF4DD0E1).withValues(alpha: opacity),
          ],
        ).createShader(stoneRect);

      canvas.drawCircle(center, radius, stonePaint);

      // Specular highlight arc
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.8 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(center.dx - radius * 0.2, center.dy - radius * 0.2), radius: radius * 0.5),
        3.8,
        1.5,
        false,
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(GomokuPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.selectedRow != selectedRow ||
        oldDelegate.selectedCol != selectedCol ||
        oldDelegate.previewPiece != previewPiece ||
        oldDelegate.lastRow != lastRow ||
        oldDelegate.lastCol != lastCol;
  }
}
