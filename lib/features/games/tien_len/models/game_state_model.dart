import 'package:cloud_firestore/cloud_firestore.dart';
import 'card_model.dart';

class GameStateModel {
  final Map<String, List<CardModel>> playerHands;
  final List<CardModel> lastPlayedCards;
  final String? lastPlayerId;
  final String currentTurnId;
  final List<String> passedPlayers;
  final List<String> winners;
  final int turnStartedAt;
  final int lastPenalty; // Tiền phạt của cú chặt trước đó trong vòng này
  final Map<String, int>? finalPayouts;
  final Map<String, dynamic>? chopEvent; // Lưu thông tin cú chặt: chopperId, victimId, amount, timestamp

  final bool isFirstTurn;
  final List<CardModel> allPlayedCards;
  final CardModel? mandatoryOpeningCard;

  GameStateModel({
    required this.playerHands,
    this.lastPlayedCards = const [],
    this.lastPlayerId,
    required this.currentTurnId,
    this.passedPlayers = const [],
    this.winners = const [],
    required this.turnStartedAt,
    this.lastPenalty = 0,
    this.finalPayouts,
    this.chopEvent,
    this.isFirstTurn = false,
    this.allPlayedCards = const [],
    this.mandatoryOpeningCard,
  });

  Map<String, dynamic> toMap() {
    return {
      'playerHands': playerHands.map((key, value) => 
          MapEntry(key, value.map((c) => c.toMap()).toList())),
      'lastPlayedCards': lastPlayedCards.map((c) => c.toMap()).toList(),
      'lastPlayerId': lastPlayerId,
      'currentTurnId': currentTurnId,
      'passedPlayers': passedPlayers,
      'winners': winners,
      'turnStartedAt': turnStartedAt,
      'lastPenalty': lastPenalty,
      'finalPayouts': finalPayouts,
      'chopEvent': chopEvent,
      'isFirstTurn': isFirstTurn,
      'allPlayedCards': allPlayedCards.map((c) => c.toMap()).toList(),
      'mandatoryOpeningCard': mandatoryOpeningCard?.toMap(),
    };
  }

  factory GameStateModel.fromMap(Map<String, dynamic> map) {
    int startedAt;
    var rawStartedAt = map['turnStartedAt'];
    if (rawStartedAt is int) {
      startedAt = rawStartedAt;
    } else if (rawStartedAt is Timestamp) {
      startedAt = rawStartedAt.millisecondsSinceEpoch;
    } else {
      startedAt = DateTime.now().millisecondsSinceEpoch;
    }

    return GameStateModel(
      playerHands: (map['playerHands'] as Map<String, dynamic>).map((key, value) =>
          MapEntry(key, (value as List).map((c) => CardModel.fromMap(c)).toList())),
      lastPlayedCards: (map['lastPlayedCards'] as List? ?? [])
          .map((c) => CardModel.fromMap(c))
          .toList(),
      lastPlayerId: map['lastPlayerId'],
      currentTurnId: map['currentTurnId'] ?? '',
      passedPlayers: List<String>.from(map['passedPlayers'] ?? []),
      winners: List<String>.from(map['winners'] ?? []),
      turnStartedAt: startedAt,
      lastPenalty: map['lastPenalty'] ?? 0,
      finalPayouts: map['finalPayouts'] != null ? Map<String, int>.from(map['finalPayouts']) : null,
      chopEvent: map['chopEvent'] != null ? Map<String, dynamic>.from(map['chopEvent']) : null,
      isFirstTurn: map['isFirstTurn'] ?? false,
      allPlayedCards: (map['allPlayedCards'] as List? ?? [])
          .map((c) => CardModel.fromMap(c))
          .toList(),
      mandatoryOpeningCard: map['mandatoryOpeningCard'] != null 
          ? CardModel.fromMap(map['mandatoryOpeningCard']) 
          : null,
    );
  }
}
