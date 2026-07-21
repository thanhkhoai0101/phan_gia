import 'package:cloud_firestore/cloud_firestore.dart';

class DrawPlayerModel {
  final String uid;
  final String displayName;
  final String? avatarUrl;
  final int score;
  final bool hasGuessed;

  DrawPlayerModel({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
    required this.score,
    required this.hasGuessed,
  });

  factory DrawPlayerModel.fromMap(Map<String, dynamic> map) {
    return DrawPlayerModel(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? 'Unknown',
      avatarUrl: map['avatarUrl'],
      score: map['score'] ?? 0,
      hasGuessed: map['hasGuessed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'score': score,
      'hasGuessed': hasGuessed,
    };
  }

  DrawPlayerModel copyWith({
    String? uid,
    String? displayName,
    String? avatarUrl,
    int? score,
    bool? hasGuessed,
  }) {
    return DrawPlayerModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      score: score ?? this.score,
      hasGuessed: hasGuessed ?? this.hasGuessed,
    );
  }
}

class DrawRoomModel {
  final String id;
  final String hostId;
  final String status; // 'waiting', 'choosing_word', 'drawing', 'round_end', 'game_over'
  final List<DrawPlayerModel> players;
  final String? currentDrawerId;
  final int currentRound;
  final int totalRounds;
  final List<String> wordChoices;
  final String secretWord;
  final DateTime? roundEndTime;
  final int betAmount;

  DrawRoomModel({
    required this.id,
    required this.hostId,
    required this.status,
    required this.players,
    this.currentDrawerId,
    required this.currentRound,
    required this.totalRounds,
    required this.wordChoices,
    required this.secretWord,
    this.roundEndTime,
    this.betAmount = 0,
  });

  factory DrawRoomModel.fromMap(Map<String, dynamic> map, String id) {
    var playersList = (map['players'] as List<dynamic>?)
            ?.map((p) => DrawPlayerModel.fromMap(p as Map<String, dynamic>))
            .toList() ??
        [];

    DateTime? endTime;
    if (map['roundEndTime'] != null) {
      endTime = (map['roundEndTime'] as Timestamp).toDate();
    }

    return DrawRoomModel(
      id: id,
      hostId: map['hostId'] ?? '',
      status: map['status'] ?? 'waiting',
      players: playersList,
      currentDrawerId: map['currentDrawerId'],
      currentRound: map['currentRound'] ?? 1,
      totalRounds: map['totalRounds'] ?? 3,
      wordChoices: List<String>.from(map['wordChoices'] ?? []),
      secretWord: map['secretWord'] ?? '',
      roundEndTime: endTime,
      betAmount: map['betAmount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'status': status,
      'players': players.map((p) => p.toMap()).toList(),
      'currentDrawerId': currentDrawerId,
      'currentRound': currentRound,
      'totalRounds': totalRounds,
      'wordChoices': wordChoices,
      'secretWord': secretWord,
      'roundEndTime': roundEndTime != null ? Timestamp.fromDate(roundEndTime!) : null,
      'betAmount': betAmount,
    };
  }
}
