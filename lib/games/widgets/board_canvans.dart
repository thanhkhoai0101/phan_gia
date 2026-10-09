import 'dart:math';
import 'package:flutter/material.dart';
import 'gomoku_painter.dart';

class BoardCanvas extends StatefulWidget {
  final List<List<int>> board;
  final bool isMyTurn;
  final int myPiece; // 1 = Black/X, 2 = White/O
  final Function(int row, int col)? onConfirmMove;
  final Function(int row, int col)? onTap; // Fallback legacy callback
  final int? lastRow;
  final int? lastCol;

  const BoardCanvas({
    super.key,
    required this.board,
    this.isMyTurn = true,
    this.myPiece = 1,
    this.onConfirmMove,
    this.onTap,
    this.lastRow,
    this.lastCol,
  });

  @override
  State<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends State<BoardCanvas> {
  int? _selectedRow;
  int? _selectedCol;

  @override
  void didUpdateWidget(BoardCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset selection if turn changes or selected cell becomes occupied
    if (!widget.isMyTurn) {
      _selectedRow = null;
      _selectedCol = null;
    } else if (_selectedRow != null && _selectedCol != null) {
      if (widget.board[_selectedRow!][_selectedCol!] != 0) {
        _selectedRow = null;
        _selectedCol = null;
      }
    }
  }

  void _handleCellTap(int row, int col) {
    if (!widget.isMyTurn) return;
    if (row < 0 || row >= 15 || col < 0 || col >= 15) return;
    if (widget.board[row][col] != 0) return; // Cell already occupied

    if (_selectedRow == row && _selectedCol == col) {
      // Tapping the already selected cell again confirms the move!
      _confirmMove();
    } else {
      // Select new cell
      setState(() {
        _selectedRow = row;
        _selectedCol = col;
      });
    }
  }

  void _confirmMove() {
    if (_selectedRow == null || _selectedCol == null) return;
    final r = _selectedRow!;
    final c = _selectedCol!;

    setState(() {
      _selectedRow = null;
      _selectedCol = null;
    });

    if (widget.onConfirmMove != null) {
      widget.onConfirmMove!(r, c);
    } else if (widget.onTap != null) {
      widget.onTap!(r, c);
    }
  }

  void _cancelSelection() {
    setState(() {
      _selectedRow = null;
      _selectedCol = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const boardSize = 15;
        final side = min(constraints.maxWidth, constraints.maxHeight);
        final margin = side * 0.05;
        final step = (side - 2 * margin) / (boardSize - 1);

        final offsetX = (constraints.maxWidth - side) / 2.0;
        final offsetY = (constraints.maxHeight - side) / 2.0;

        // Position of teardrop pin badge pointing at cell intersection
        double? pinLeft;
        double? pinTop;

        if (_selectedRow != null && _selectedCol != null) {
          final stoneX = offsetX + margin + _selectedCol! * step;
          final stoneY = offsetY + margin + _selectedRow! * step;

          // Teardrop pin tip (bottom center of 40x48 widget) touches intersection (stoneX, stoneY)
          pinLeft = stoneX - 20.0;
          pinTop = stoneY - 44.0;
        }

        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Fixed Board Canvas (Centered)
              Positioned(
                left: offsetX,
                top: offsetY,
                width: side,
                height: side,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final dx = details.localPosition.dx;
                    final dy = details.localPosition.dy;

                    final relX = dx - margin;
                    final relY = dy - margin;

                    final col = (relX / step).round();
                    final row = (relY / step).round();

                    if (row >= 0 && row < boardSize && col >= 0 && col < boardSize) {
                      _handleCellTap(row, col);
                    }
                  },
                  child: CustomPaint(
                    painter: GomokuPainter(
                      board: widget.board,
                      selectedRow: _selectedRow,
                      selectedCol: _selectedCol,
                      previewPiece: widget.myPiece,
                      lastRow: widget.lastRow,
                      lastCol: widget.lastCol,
                    ),
                    size: Size(side, side),
                  ),
                ),
              ),

              // 2. Teardrop Checkmark Pin Marker Badge over selected intersection
              if (_selectedRow != null && _selectedCol != null && pinLeft != null && pinTop != null)
                Positioned(
                  left: pinLeft,
                  top: pinTop,
                  child: TeardropPinWidget(
                    onTap: _confirmMove,
                  ),
                ),

              // 3. Floating Celestial Confirm Action Bar Overlay (Non-shifting)
              if (_selectedRow != null && _selectedCol != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 4,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2634).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF4EE2EC), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                            blurRadius: 14,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF80DEEA).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF80DEEA).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              "Hàng ${_selectedRow! + 1}, Cột ${_selectedCol! + 1}",
                              style: const TextStyle(
                                color: Color(0xFFE0F7FA),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Row(children: [// Cancel Button
                            GestureDetector(
                              onTap: _cancelSelection,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                                    SizedBox(width: 4),
                                    Text("Hủy", style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 10,),
                            // Confirm Tick Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E5FF),
                                foregroundColor: const Color(0xFF0D1B2A),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 6,
                                shadowColor: const Color(0xFF00E5FF),
                              ),
                              onPressed: _confirmMove,
                              icon: const Icon(Icons.check_rounded, size: 18, color: Color(0xFF0D1B2A)),
                              label: const Text(
                                "ĐÁNH",
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                              ),
                            ),],)
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Teardrop Pin Marker Checkmark Badge (con ghim giọt nước)
class TeardropPinWidget extends StatelessWidget {
  final VoidCallback onTap;

  const TeardropPinWidget({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        size: const Size(40, 48),
        painter: _TeardropPainter(),
        child: const SizedBox(
          width: 40,
          height: 48,
          child: Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Icon(
              Icons.check_rounded,
              color: Color(0xFF0F2634),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _TeardropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Teardrop / Map Pin Path pointing down to (w/2, h)
    path.moveTo(w / 2, h); // Bottom sharp tip
    path.cubicTo(w * 0.05, h * 0.65, 0, h * 0.45, 0, w / 2); // Left curve up
    path.arcToPoint(Offset(w, w / 2), radius: Radius.circular(w / 2), clockwise: true); // Top dome
    path.cubicTo(w, h * 0.45, w * 0.95, h * 0.65, w / 2, h); // Right curve down
    path.close();

    // Outer Glow
    final shadowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, shadowPaint);

    // Luminous Cyan-White Glass Gradient
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white,
          Color(0xFFE0F7FA),
          Color(0xFF80DEEA),
          Color(0xFF00E5FF),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, bodyPaint);

    // White Highlight Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_TeardropPainter oldDelegate) => false;
}
