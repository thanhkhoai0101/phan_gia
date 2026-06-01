import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../services/auth_service.dart';
import '../models/bau_cua_model.dart';

class BauCuaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  dynamic get currentUser => _authService.currentUser;

  Stream<List<BauCuaRoom>> streamRooms() {
    return _firestore
        .collection('bau_cua_rooms')
        .orderBy('lastRollAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BauCuaRoom.fromFirestore(doc))
            .toList());
  }

  Stream<BauCuaRoom> streamRoom(String roomId) {
    return _firestore
        .collection('bau_cua_rooms')
        .doc(roomId)
        .snapshots()
        .map((doc) => BauCuaRoom.fromFirestore(doc));
  }

  Future<String> createRoom(String hostName, int betLimit) async {
    final user = _authService.currentUser;
    if (user == null) throw Exception('User not logged in');

    final roomDoc = _firestore.collection('bau_cua_rooms').doc();
    final room = BauCuaRoom(
      id: roomDoc.id,
      hostUid: user.uid,
      hostName: hostName,
      status: 'waiting',
      resultDice: [],
      betLimit: betLimit,
      lastRollAt: Timestamp.now(),
      players: [
        BauCuaPlayer(uid: user.uid, displayName: hostName, balance: 0) // Balance updated on join
      ],
      currentBets: [],
      timerSeconds: 0,
    );

    await roomDoc.set(room.toMap());
    return roomDoc.id;
  }

  Future<void> joinRoom(String roomId, String displayName, num balance) async {
    final user = _authService.currentUser;
    if (user == null) return;

    final player = BauCuaPlayer(uid: user.uid, displayName: displayName, balance: balance);
    
    await _firestore.collection('bau_cua_rooms').doc(roomId).update({
      'players': FieldValue.arrayUnion([player.toMap()])
    });
  }

  Future<void> placeBet(String roomId, int mascotIndex, int amount, String userName) async {
    final user = _authService.currentUser;
    if (user == null) return;

    final bet = BauCuaBet(
      userId: user.uid,
      userName: userName,
      mascotIndex: mascotIndex,
      amount: amount,
    );

    // Also deduct from user balance in Firestore
    await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection('users').doc(user.uid);
      final roomRef = _firestore.collection('bau_cua_rooms').doc(roomId);

      final userDoc = await transaction.get(userRef);
      final currentBalance = userDoc.data()?['balance'] ?? 0;

      if (currentBalance < amount) {
        throw Exception('Không đủ số dư');
      }

      transaction.update(userRef, {'balance': currentBalance - amount});
      transaction.update(roomRef, {
        'currentBets': FieldValue.arrayUnion([bet.toMap()])
      });
    });
  }

  Future<void> updateRoomStatus(String roomId, String status, {List<int>? resultDice, int? timer}) async {
    Map<String, dynamic> updates = {'status': status};
    if (resultDice != null) updates['resultDice'] = resultDice;
    if (timer != null) updates['timerSeconds'] = timer;
    if (status == 'rolling') updates['lastRollAt'] = Timestamp.now();
    
    await _firestore.collection('bau_cua_rooms').doc(roomId).update(updates);
  }

  Future<void> settleBets(String roomId, List<int> resultDice) async {
    final roomDoc = await _firestore.collection('bau_cua_rooms').doc(roomId).get();
    if (!roomDoc.exists) return;

    final room = BauCuaRoom.fromFirestore(roomDoc);
    final bets = room.currentBets;

    Map<String, int> winnings = {}; // userId -> amount

    for (var bet in bets) {
      int matchCount = resultDice.where((d) => d == bet.mascotIndex).length;
      if (matchCount > 0) {
        // Payout = Bet + (MatchCount * Bet)
        int winAmount = bet.amount + (matchCount * bet.amount);
        winnings[bet.userId] = (winnings[bet.userId] ?? 0) + winAmount;
      }
    }

    // Apply winnings to users
    final batch = _firestore.batch();
    for (var userId in winnings.keys) {
      batch.update(_firestore.collection('users').doc(userId), {
        'balance': FieldValue.increment(winnings[userId]!)
      });
    }

    // Clear bets for next round and update history
    List<List<int>> newHistory = List.from(room.history);
    newHistory.insert(0, resultDice);
    if (newHistory.length > 20) newHistory = newHistory.sublist(0, 20);

    // Convert to flat list of strings for Firestore compatibility
    List<String> historyStrings = newHistory.map((h) => h.join(',')).toList();

    batch.update(_firestore.collection('bau_cua_rooms').doc(roomId), {
      'currentBets': [],
      'status': 'result',
      'timerSeconds': 5, // Show result for 5 seconds
      'history': historyStrings,
    });

    await batch.commit();
  }

  Future<void> leaveRoom(String roomId) async {
    final user = _authService.currentUser;
    if (user == null) return;

    final roomDoc = await _firestore.collection('bau_cua_rooms').doc(roomId).get();
    if (!roomDoc.exists) return;

    final room = BauCuaRoom.fromFirestore(roomDoc);
    final updatedPlayers = room.players.where((p) => p.uid != user.uid).toList();

    if (updatedPlayers.isEmpty) {
      await _firestore.collection('bau_cua_rooms').doc(roomId).delete();
    } else {
      await _firestore.collection('bau_cua_rooms').doc(roomId).update({
        'players': updatedPlayers.map((p) => p.toMap()).toList()
      });
    }
  }
}
