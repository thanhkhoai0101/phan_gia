import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/draw_guess/stroke_model.dart';
import '../../services/draw_guess/draw_guess_service.dart';

class DrawCanvasState {
  final int selectedColor;
  final double strokeWidth;
  final List<StrokeModel> currentStrokes;
  final StrokeModel? activeStroke;

  DrawCanvasState({
    this.selectedColor = 0xFF000000,
    this.strokeWidth = 4.0,
    this.currentStrokes = const [],
    this.activeStroke,
  });

  DrawCanvasState copyWith({
    int? selectedColor,
    double? strokeWidth,
    List<StrokeModel>? currentStrokes,
    StrokeModel? activeStroke,
  }) {
    return DrawCanvasState(
      selectedColor: selectedColor ?? this.selectedColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      currentStrokes: currentStrokes ?? this.currentStrokes,
      activeStroke: activeStroke ?? this.activeStroke,
    );
  }
}

class DrawCanvasCubit extends Cubit<DrawCanvasState> {
  final DrawGuessService _service;
  final String roomId;
  final String currentUserId;
  
  StreamSubscription? _strokesSub;

  DrawCanvasCubit(this._service, this.roomId, this.currentUserId) : super(DrawCanvasState()) {
    _listenToStrokes();
  }

  void _listenToStrokes() {
    _strokesSub = _service.listenStrokes(roomId).listen((strokes) {
      emit(state.copyWith(currentStrokes: strokes));
    });
  }

  void changeColor(int color) {
    emit(state.copyWith(selectedColor: color));
  }

  void changeStrokeWidth(double width) {
    emit(state.copyWith(strokeWidth: width));
  }

  void startStroke(double x, double y) {
    final strokeId = '${DateTime.now().millisecondsSinceEpoch}_$currentUserId';
    final newStroke = StrokeModel(
      id: strokeId,
      drawerId: currentUserId,
      color: state.selectedColor,
      strokeWidth: state.strokeWidth,
      points: [DrawPoint(x, y)],
    );
    emit(state.copyWith(activeStroke: newStroke));
  }

  void updateStroke(double x, double y) {
    if (state.activeStroke != null) {
      final updatedPoints = List<DrawPoint>.from(state.activeStroke!.points)..add(DrawPoint(x, y));
      final updatedStroke = StrokeModel(
        id: state.activeStroke!.id,
        drawerId: state.activeStroke!.drawerId,
        color: state.activeStroke!.color,
        strokeWidth: state.activeStroke!.strokeWidth,
        points: updatedPoints,
      );
      emit(state.copyWith(activeStroke: updatedStroke));
    }
  }

  void endStroke() {
    if (state.activeStroke != null) {
      // Save to firestore
      _service.saveStroke(roomId, state.activeStroke!);
      emit(state.copyWith(activeStroke: null));
    }
  }

  void clearCanvas() {
    _service.clearCanvas(roomId);
  }

  @override
  Future<void> close() {
    _strokesSub?.cancel();
    return super.close();
  }
}
