import 'package:cloud_firestore/cloud_firestore.dart';

class BauCuaRoom {
  final String id;
  final String hostUid;
  final String hostName;
  final String status; // 'waiting', 'betting', 'rolling', 'result'
  final List<int> resultDice; // Indices 0-5
  final int betLimit;
  final Timestamp? lastRollAt;
  final List<BauCuaPlayer> players;
  final List<BauCuaBet> currentBets;
  final int timerSeconds;
  final List<List<int>> history;

  BauCuaRoom({
    required this.id,
    required this.hostUid,
    required this.hostName,
    required this.status,
    required this.resultDice,
    required this.betLimit,
    this.lastRollAt,
    required this.players,
    required this.currentBets,
    required this.timerSeconds,
    this.history = const [],
  });

  factory BauCuaRoom.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Parse history safely (it was List<List<int>>, now converting to support List<String> or old format)
    List<List<int>> parsedHistory = [];
    final historyData = data['history'] as List? ?? [];
    for (var item in historyData) {
      if (item is String) {
        parsedHistory.add(item.split(',').map((e) => int.parse(e.trim())).toList());
      } else if (item is List) {
        parsedHistory.add(List<int>.from(item));
      }
    }

    return BauCuaRoom(
      id: doc.id,
      hostUid: data['hostUid'] ?? '',
      hostName: data['hostName'] ?? '',
      status: data['status'] ?? 'waiting',
      resultDice: List<int>.from(data['resultDice'] ?? []),
      betLimit: data['betLimit'] ?? 0,
      lastRollAt: data['lastRollAt'],
      players: (data['players'] as List? ?? [])
          .map((p) => BauCuaPlayer.fromMap(p))
          .toList(),
      currentBets: (data['currentBets'] as List? ?? [])
          .map((b) => BauCuaBet.fromMap(b))
          .toList(),
      timerSeconds: data['timerSeconds'] ?? 0,
      history: parsedHistory,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostUid': hostUid,
      'hostName': hostName,
      'status': status,
      'resultDice': resultDice,
      'betLimit': betLimit,
      'lastRollAt': lastRollAt,
      'players': players.map((p) => p.toMap()).toList(),
      'currentBets': currentBets.map((b) => b.toMap()).toList(),
      'timerSeconds': timerSeconds,
      'history': history.map((h) => h.join(',')).toList(),
    };
  }
}

class BauCuaPlayer {
  final String uid;
  final String displayName;
  final num balance;
  final bool isReady;

  BauCuaPlayer({
    required this.uid,
    required this.displayName,
    required this.balance,
    this.isReady = false,
  });

  factory BauCuaPlayer.fromMap(Map<String, dynamic> map) {
    return BauCuaPlayer(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? '',
      balance: map['balance'] ?? 0,
      isReady: map['isReady'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'balance': balance,
      'isReady': isReady,
    };
  }
}

class BauCuaBet {
  final String userId;
  final String userName;
  final int mascotIndex; // 0: Nai, 1: Bầu, 2: Gà, 3: Tôm, 4: Cua, 5: Cá
  final int amount;

  BauCuaBet({
    required this.userId,
    required this.userName,
    required this.mascotIndex,
    required this.amount,
  });

  factory BauCuaBet.fromMap(Map<String, dynamic> map) {
    return BauCuaBet(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      mascotIndex: map['mascotIndex'] ?? 0,
      amount: map['amount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'mascotIndex': mascotIndex,
      'amount': amount,
    };
  }
}
