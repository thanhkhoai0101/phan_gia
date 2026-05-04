import 'game_state_model.dart';

class RoomModel {
  final String id; // Use as the short 6-character room ID
  final String hostId;
  final List<String> players; // List of player UIDs
  final String ruleType; // 'per_card' or 'sacrifice'
  final int betAmount;
  final String status; // 'waiting' or 'playing'
  final int createdAt;
  final List<String> readyPlayers; // List of player UIDs who are ready
  final GameStateModel? gameState;

  final Map<String, int> botBalances; // botUid -> balance

  RoomModel({
    required this.id,
    required this.hostId,
    required this.players,
    this.readyPlayers = const [],
    this.botBalances = const {},
    required this.ruleType,
    required this.betAmount,
    required this.status,
    required this.createdAt,
    this.gameState,
  });

  factory RoomModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RoomModel(
      id: documentId,
      hostId: map['hostId'] ?? '',
      players: List<String>.from(map['players'] ?? []),
      readyPlayers: List<String>.from(map['readyPlayers'] ?? []),
      botBalances: Map<String, int>.from(map['botBalances'] ?? {}),
      ruleType: map['ruleType'] ?? 'per_card',
      betAmount: map['betAmount'] ?? 10000,
      status: map['status'] ?? 'waiting',
      createdAt: map['createdAt'] ?? 0,
      gameState: map['gameState'] != null ? GameStateModel.fromMap(map['gameState']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'players': players,
      'readyPlayers': readyPlayers,
      'botBalances': botBalances,
      'ruleType': ruleType,
      'betAmount': betAmount,
      'status': status,
      'createdAt': createdAt,
      'gameState': gameState?.toMap(),
    };
  }
}
