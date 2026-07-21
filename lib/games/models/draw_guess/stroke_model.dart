class DrawPoint {
  final double x;
  final double y;
  
  DrawPoint(this.x, this.y);

  factory DrawPoint.fromMap(Map<String, dynamic> map) {
    return DrawPoint(
      (map['x'] ?? 0).toDouble(),
      (map['y'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
    };
  }
}

class StrokeModel {
  final String id;
  final String drawerId;
  final int color;
  final double strokeWidth;
  final List<DrawPoint> points;

  StrokeModel({
    required this.id,
    required this.drawerId,
    required this.color,
    required this.strokeWidth,
    required this.points,
  });

  factory StrokeModel.fromMap(Map<String, dynamic> map, String id) {
    var pointsList = (map['points'] as List<dynamic>?)
            ?.map((p) => DrawPoint.fromMap(p as Map<String, dynamic>))
            .toList() ??
        [];

    return StrokeModel(
      id: id,
      drawerId: map['drawerId'] ?? '',
      color: map['color'] ?? 0xFF000000,
      strokeWidth: (map['strokeWidth'] ?? 4.0).toDouble(),
      points: pointsList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'drawerId': drawerId,
      'color': color,
      'strokeWidth': strokeWidth,
      'points': points.map((p) => p.toMap()).toList(),
    };
  }
}
