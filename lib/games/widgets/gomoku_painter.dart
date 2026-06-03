import 'package:flutter/material.dart';

class GomokuPainter extends CustomPainter {
  final List<List<int>> board;
  
  // Mảng lưu vị trí vừa đánh (nếu cần highlight)
  // final int? lastRow;
  // final int? lastCol;

  GomokuPainter(this.board);

  @override
  void paint(Canvas canvas, Size size) {
    const boardSize = 15;
    
    // Draw wooden background
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE4C08F), // Light wood
          Color(0xFFC08A4A), // Dark wood
        ],
      ).createShader(bgRect);
      
    // Thêm viền gỗ đậm
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(8)),
      bgPaint,
    );

    // Draw lines
    final linePaint = Paint()
      ..color = const Color(0xFF6B4226).withOpacity(0.8) // Dark brown
      ..strokeWidth = 1.5;

    final cell = size.width / boardSize;

    // Vẽ lưới (vẽ ở giữa mỗi cell)
    for (int i = 0; i < boardSize; i++) {
      // Dọc
      canvas.drawLine(
        Offset(cell * i + cell / 2, cell / 2),
        Offset(cell * i + cell / 2, size.height - cell / 2),
        linePaint,
      );

      // Ngang
      canvas.drawLine(
        Offset(cell / 2, cell * i + cell / 2),
        Offset(size.width - cell / 2, cell * i + cell / 2),
        linePaint,
      );
    }
    
    // Vẽ các dấu chấm hoa thị (Thiên nguyên, sao)
    final starPoints = [
      [3, 3], [3, 11], [11, 3], [11, 11], [7, 7]
    ];
    final starPaint = Paint()..color = const Color(0xFF6B4226);
    for (var point in starPoints) {
      final center = Offset(
        point[1] * cell + cell / 2,
        point[0] * cell + cell / 2,
      );
      canvas.drawCircle(center, cell * 0.1, starPaint);
    }

    // Draw stones
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (board[r][c] == 0) continue;

        final center = Offset(
          c * cell + cell / 2,
          r * cell + cell / 2,
        );

        // Vẽ bóng đổ cho quân cờ
        final shadowPaint = Paint()
          ..color = Colors.black.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        canvas.drawCircle(
          Offset(center.dx + 2, center.dy + 2),
          cell * 0.42,
          shadowPaint,
        );

        // Vẽ quân cờ nổi 3D bằng Gradient
        final stoneRect = Rect.fromCircle(center: center, radius: cell * 0.42);
        
        final isBlack = board[r][c] == 1;
        
        final stonePaint = Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            radius: 0.8,
            colors: isBlack 
                ? [const Color(0xFF666666), Colors.black]
                : [Colors.white, const Color(0xFFCCCCCC)],
          ).createShader(stoneRect);

        canvas.drawCircle(
          center,
          cell * 0.42,
          stonePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(GomokuPainter oldDelegate) => true; // Ideally check if board changed
}
