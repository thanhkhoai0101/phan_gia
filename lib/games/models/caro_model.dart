class CaroModel {
  final String roomId;
  final String hostId;
  final String guestId;
  final int turn;
  final int winner;
  final String status;
  final List<List<int>> board;
  final String hostName;
  final String guestName;

  CaroModel({
    required this.roomId,
    required this.hostId,
    required this.guestId,
    required this.turn,
    required this.winner,
    required this.status,
    required this.board,
    required this.hostName,
    required this.guestName,
  });

  factory CaroModel.fromJson(Map<String, dynamic> json) {
    final raw = json['board'] as List;
    List<List<int>> board;

    // Hỗ trợ cả 2 format: 1D flat (mới) và 2D nested (cũ - nếu có)
    if (raw.isNotEmpty && raw[0] is List) {
      // Format cũ: nested array
      board = raw.map((e) => List<int>.from(e)).toList();
    } else {
      // Format mới: flat array 1D -> chuyển về 2D 15x15
      final flat = List<int>.from(raw);
      board = List.generate(
        15,
        (r) => flat.sublist(r * 15, r * 15 + 15),
      );
    }

    return CaroModel(
      roomId: json['roomId'],
      hostId: json['hostId'],
      guestId: json['guestId'],
      turn: json['turn'],
      winner: json['winner'],
      status: json['status'],
      board: board,
      hostName: json['hostName'] ?? '',
      guestName: json['guestName'] ?? '',
    );
  }

  /// Chuyển bàn cờ 2D thành 1D để lưu Firestore (không hỗ trợ nested arrays)
  static List<int> boardToFlat(List<List<int>> board) {
    return board.expand((row) => row).toList();
  }
}
