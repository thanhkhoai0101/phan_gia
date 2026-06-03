import 'package:flutter/material.dart';

import 'gomoku_painter.dart';

class BoardCanvas extends StatelessWidget {
  final List<List<int>> board;
  final Function(int row, int col)? onTap;

  const BoardCanvas({
    super.key,
    required this.board,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            if (onTap == null) return;
            
            const boardSize = 15;
            final cell = constraints.maxWidth / boardSize;
            
            final col = (details.localPosition.dx / cell).floor();
            final row = (details.localPosition.dy / cell).floor();
            
            if (row >= 0 && row < boardSize && col >= 0 && col < boardSize) {
              onTap!(row, col);
            }
          },
          child: CustomPaint(
            painter: GomokuPainter(
              board,
            ),
            size: Size.infinite,
          ),
        );
      }
    );
  }
}
