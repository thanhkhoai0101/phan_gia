import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/draw_guess/draw_canvas_cubit.dart';
import '../../../models/draw_guess/stroke_model.dart';

class DrawCanvasWidget extends StatelessWidget {
  final bool isDrawer;

  const DrawCanvasWidget({super.key, required this.isDrawer});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DrawCanvasCubit, DrawCanvasState>(
      builder: (context, state) {
        return Column(
          children: [
            if (isDrawer) _buildToolbar(context, state),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.purple.shade300, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onPanStart: isDrawer ? (details) {
                          final renderBox = context.findRenderObject() as RenderBox;
                          final pos = renderBox.globalToLocal(details.globalPosition);
                          context.read<DrawCanvasCubit>().startStroke(
                            pos.dx / constraints.maxWidth,
                            pos.dy / constraints.maxHeight,
                          );
                        } : null,
                        onPanUpdate: isDrawer ? (details) {
                          final renderBox = context.findRenderObject() as RenderBox;
                          final pos = renderBox.globalToLocal(details.globalPosition);
                          context.read<DrawCanvasCubit>().updateStroke(
                            pos.dx / constraints.maxWidth,
                            pos.dy / constraints.maxHeight,
                          );
                        } : null,
                        onPanEnd: isDrawer ? (details) {
                          context.read<DrawCanvasCubit>().endStroke();
                        } : null,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _DrawPainter(
                            strokes: state.currentStrokes,
                            activeStroke: state.activeStroke,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static const _colors = [
    0xFF000000, // Black
    0xFFE53935, // Red
    0xFF43A047, // Green
    0xFF1E88E5, // Blue
    0xFFFDD835, // Yellow
    0xFFFF6F00, // Orange
    0xFF8E24AA, // Purple
    0xFF00ACC1, // Cyan
    0xFF6D4C41, // Brown
    0xFFFFFFFF, // White (Eraser)
  ];

  Widget _buildToolbar(BuildContext context, DrawCanvasState state) {
    final strokeWidths = [2.0, 5.0, 10.0, 18.0];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF2D0D4E),
        border: Border(bottom: BorderSide(color: Color(0xFF4A148C))),
      ),
      child: Row(
        children: [
          // Color swatches
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _colors.map((c) => GestureDetector(
                  onTap: () => context.read<DrawCanvasCubit>().changeColor(c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: state.selectedColor == c ? Colors.amber : Colors.white38,
                        width: state.selectedColor == c ? 2.5 : 1,
                      ),
                    ),
                    child: c == 0xFFFFFFFF
                        ? const Icon(Icons.auto_fix_high, size: 14, color: Colors.grey)
                        : null,
                  ),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Divider
          Container(width: 1, height: 28, color: Colors.white24),
          const SizedBox(width: 4),
          // Stroke width
          Row(
            children: strokeWidths.map((w) => GestureDetector(
              onTap: () => context.read<DrawCanvasCubit>().changeStrokeWidth(w),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: state.strokeWidth == w ? Colors.amber : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: w.clamp(2, 18),
                    height: w.clamp(2, 18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(state.selectedColor),
                    ),
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(width: 4),
          Container(width: 1, height: 28, color: Colors.white24),
          // Clear button
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 22),
            onPressed: () => context.read<DrawCanvasCubit>().clearCanvas(),
            tooltip: 'Xóa toàn bộ',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _DrawPainter extends CustomPainter {
  final List<StrokeModel> strokes;
  final StrokeModel? activeStroke;

  _DrawPainter({required this.strokes, this.activeStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void drawStroke(StrokeModel stroke) {
      if (stroke.points.isEmpty) return;
      paint.color = Color(stroke.color);
      paint.strokeWidth = stroke.strokeWidth;

      final path = Path();
      path.moveTo(stroke.points.first.x * size.width, stroke.points.first.y * size.height);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].x * size.width, stroke.points[i].y * size.height);
      }
      canvas.drawPath(path, paint);
    }

    for (final stroke in strokes) {
      drawStroke(stroke);
    }
    if (activeStroke != null) {
      drawStroke(activeStroke!);
    }
  }

  @override
  bool shouldRepaint(covariant _DrawPainter oldDelegate) => true;
}
