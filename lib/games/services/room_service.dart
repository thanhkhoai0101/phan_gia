import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../../../../services/notification_service.dart';
import '../models/card_model.dart';
import '../models/game_state_model.dart';
import '../logic/tien_len_logic.dart';
import '../models/room_model.dart';
import 'game_engine.dart';

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _generateRoomId() {
    var rng = Random();
    String code = '';
    for (var i = 0; i < 6; i++) code += rng.nextInt(10).toString();
    return code;
  }

  // --- ROOM MGMT ---
  Future<String?> createRoom(String hostId, String ruleType, int betAmount) async {
    try {
      String roomId = _generateRoomId();
      RoomModel newRoom = RoomModel(
        id: roomId,
        hostId: hostId,
        players: [hostId],
        ruleType: ruleType,
        betAmount: betAmount,
        status: 'waiting',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      Map<String, dynamic> data = newRoom.toMap();
      data['isFirstGame'] = true;
      await _firestore.collection('rooms').doc(roomId).set(data);
      return roomId;
    } catch (e) { return null; }
  }

  Future<String?> joinRoom(String roomId, String userId) async {
    try {
      DocumentReference roomRef = _firestore.collection('rooms').doc(roomId);
      return await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return "Phòng không tồn tại!";
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        List<String> players = List<String>.from(data['players'] ?? []);
        
        // Cho phép vào phòng xem dù đang chơi, miễn là phòng chưa đầy (tối đa 4 người)
        if (players.length >= 4) return "Phòng đã đầy!";
        if (!players.contains(userId)) {
          players.add(userId);
          transaction.update(roomRef, {'players': players});
        }
        return null;
      });
    } catch (e) { return "Lỗi."; }
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    try {
      DocumentReference roomRef = _firestore.collection('rooms').doc(roomId);
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        List<String> players = List<String>.from(data['players'] ?? []);
        if (players.contains(userId)) {
          players.remove(userId);
          
          bool hasHuman = players.any((p) => !p.startsWith('bot_'));
          if (!hasHuman) {
            transaction.delete(roomRef);
          } else {
            Map<String, dynamic> updates = {'players': players};
            // Tự động đổi chủ phòng nếu chủ phòng thoát
            if (data['hostId'] == userId) {
              // Tìm người chơi đầu tiên KHÔNG phải là bot
              String? newHost = players.firstWhere((p) => !p.startsWith('bot_'), orElse: () => players.first);
              updates['hostId'] = newHost;
            }
            // Nếu người chơi đang trong lượt mà thoát thì tự động bỏ qua (skip) ở client hoặc timer sẽ xử lý. 
            // Cập nhật readyPlayers để họ không kẹt lại ở ván sau
            List<String> ready = List<String>.from(data['readyPlayers'] ?? []);
            if (ready.contains(userId)) {
              ready.remove(userId);
              updates['readyPlayers'] = ready;
            }
            transaction.update(roomRef, updates);
          }
        }
      });
    } catch (e) {}
  }

  Future<void> kickPlayer(String roomId, String hostId, String targetId) async {
    try {
      DocumentReference roomRef = _firestore.collection('rooms').doc(roomId);
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        if (data['hostId'] != hostId) return; // Chỉ chủ phòng mới được kích
        
        List<String> players = List<String>.from(data['players'] ?? []);
        if (players.contains(targetId)) {
          players.remove(targetId);
          
          bool hasHuman = players.any((p) => !p.startsWith('bot_'));
          if (!hasHuman) {
            transaction.delete(roomRef);
          } else {
            transaction.update(roomRef, {'players': players});
          }
        }
      });
    } catch (e) {}
  }

  Future<String?> toggleReady(String roomId, String userId) async {
    try {
      DocumentReference roomRef = _firestore.collection('rooms').doc(roomId);
      return await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return "Phòng không tồn tại!";
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        List<String> readyPlayers = List<String>.from(data['readyPlayers'] ?? []);
        int betAmount = data['betAmount'] ?? 0;

        DocumentSnapshot userSnapshot = await transaction.get(_firestore.collection('users').doc(userId));
        int balance = userSnapshot.get('balance') ?? 0;
        
        // Yêu cầu tối thiểu 1 ván cược để sẵn sàng
        if (balance < betAmount) return "Bạn không đủ tiền cược!";

        if (readyPlayers.contains(userId)) {
          readyPlayers.remove(userId);
        } else {
          readyPlayers.add(userId);
        }
        transaction.update(roomRef, {'readyPlayers': readyPlayers});
        return null;
      });
    } catch (e) {
      return e.toString();
    }
  }

  // --- GAME LOGIC ---
  Future<void> startGame(String roomId) async {
    try {
      DocumentReference roomRef = _firestore.collection('rooms').doc(roomId);
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        List<String> players = List<String>.from(data['players'] ?? []);
        List<String> readyPlayers = List<String>.from(data['readyPlayers'] ?? []);
        
        if (players.length < 2) return;
        // All players (except host maybe, or including host) must be ready
        // Usually, host starts, and others must be ready.
        for (var p in players) {
          if (p != data['hostId'] && !readyPlayers.contains(p)) return;
        }

        final hands = GameEngine.dealCards(players);
        String firstPlayer = players.first;
        CardModel? minCard;

        if (data['isFirstGame'] == true) {
          // Tìm lá bài nhỏ nhất trong tất cả các tay bài (thường là 3 Bích)
          for (var entry in hands.entries) {
            for (var card in entry.value) {
              if (minCard == null || card.value < minCard.value) {
                minCard = card;
                firstPlayer = entry.key;
              }
            }
          }
        } else {
          firstPlayer = data['lastWinnerId'] ?? players.first;
        }

        final initialGameState = GameStateModel(
          playerHands: hands,
          currentTurnId: firstPlayer,
          turnStartedAt: DateTime.now().millisecondsSinceEpoch,
          lastPenalty: 0,
          winners: [],
          isFirstTurn: data['isFirstGame'] == true,
          allPlayedCards: [],
          mandatoryOpeningCard: minCard,
        );

        Map<String, dynamic> gameStateMap = initialGameState.toMap();
        gameStateMap['turnStartedAt'] = FieldValue.serverTimestamp();

        transaction.update(roomRef, {
          'status': 'playing',
          'gameState': gameStateMap,
          'isFirstGame': false,
          'readyPlayers': [], // Reset ready for next round
        });
      });
    } catch (e) {}
  }

  Future<void> playCards(String roomId, String userId, List<CardModel> selectedCards) async {
    try {
      DocumentReference roomRef = _firestore.collection('rooms').doc(roomId);
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;
        RoomModel room = RoomModel.fromMap(snapshot.data() as Map<String, dynamic>, snapshot.id);
        
        bool isNewRound = room.gameState!.lastPlayedCards.isEmpty;
        bool is4DoubleSeq = TienLenLogic.analyzeHand(selectedCards).type == HandType.fourDoubleSequence;

        if (room.gameState?.currentTurnId != userId) {
          if (!is4DoubleSeq || isNewRound) return;
        }

        if (!TienLenLogic.canPlay(
          room.gameState!.lastPlayedCards, 
          selectedCards, 
          isNewRound, 
          isFirstTurn: room.gameState!.isFirstTurn,
          mandatoryCard: room.gameState!.mandatoryOpeningCard,
        )) return;

        int newPenalty = 0;
        if (!isNewRound && room.gameState!.lastPlayerId != null) {
          newPenalty = _applyChopPenalty(transaction, room, userId, room.gameState!.lastPlayerId!, selectedCards);
        }

        Map<String, List<CardModel>> newHands = Map.from(room.gameState!.playerHands);
        List<CardModel> currentHand = newHands[userId] ?? [];
        for (var card in selectedCards) {
          currentHand.removeWhere((c) => c.rank == card.rank && c.suit == card.suit);
        }
        newHands[userId] = currentHand;

        // CẬP NHẬT GAME STATE (LUÔN CẬP NHẬT ĐỂ TRÁNH LỖI VỀ)
        Map<String, dynamic> updates = {
          'gameState.playerHands.$userId': currentHand.map((c) => c.toMap()).toList(),
          'gameState.lastPlayedCards': selectedCards.map((c) => c.toMap()).toList(),
          'gameState.lastPlayerId': userId,
          'gameState.isFirstTurn': false,
          'gameState.allPlayedCards': FieldValue.arrayUnion(selectedCards.map((c) => c.toMap()).toList()),
        };

        if (newPenalty > 0 && room.gameState!.lastPlayerId != null) {
          updates['gameState.chopEvent'] = {
            'chopperId': userId,
            'victimId': room.gameState!.lastPlayerId,
            'amount': newPenalty,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
        }

        if (currentHand.isEmpty) {
          List<String> newWinners = List<String>.from(room.gameState!.winners);
          if (!newWinners.contains(userId)) newWinners.add(userId);
          
          bool isGameOver = false;
          if (room.ruleType == 'per_card') {
            isGameOver = true;
          } else {
            if (newWinners.length >= room.players.length - 1) {
              isGameOver = true;
            }
          }

          if (isGameOver) {
            updates['status'] = 'finished';
            updates['gameState.winners'] = newWinners;
            updates['lastWinnerId'] = newWinners.first;
            Map<String, int> payouts = _calculateFinalPayouts(transaction, room, newWinners);
            updates['gameState.finalPayouts'] = payouts;
          } else {
            updates['gameState.winners'] = newWinners;
            String nextId = _getNextActivePlayer(room.players, userId, [...room.gameState!.passedPlayers, ...newWinners]);
            updates['gameState.currentTurnId'] = nextId;
            updates['gameState.turnStartedAt'] = FieldValue.serverTimestamp();
            updates['gameState.lastPenalty'] = 0; // Reset penalty when someone finishes?
          }
        } else {
          String nextId = _getNextActivePlayer(room.players, userId, [...room.gameState!.passedPlayers, ...room.gameState!.winners]);
          updates['gameState.currentTurnId'] = nextId;
          updates['gameState.turnStartedAt'] = FieldValue.serverTimestamp();
          updates['gameState.lastPenalty'] = newPenalty > 0 ? newPenalty : (isNewRound ? 0 : room.gameState!.lastPenalty);
        }

        transaction.update(roomRef, updates);
      });
    } catch (e) {
      print("Lỗi đánh bài: $e");
    }
  }

  Map<String, int> _calculateFinalPayouts(Transaction transaction, RoomModel room, List<String> winners) {
    String ruleType = room.ruleType;
    int bet = room.betAmount;
    Map<String, int> payouts = {};
    
    if (ruleType == 'per_card') {
      String winnerId = winners.first;
      int totalWin = 0;
      for (var pid in room.players) {
        if (pid != winnerId) {
          int cardsLeft = room.gameState!.playerHands[pid]?.length ?? 0;
          int loss = cardsLeft * bet;
          totalWin += loss;
          payouts[pid] = -loss;
          if (!pid.startsWith('bot_')) {
            transaction.update(_firestore.collection('users').doc(pid), {'balance': FieldValue.increment(-loss)});
          }
        }
      }
      payouts[winnerId] = totalWin;
      if (!winnerId.startsWith('bot_')) {
        transaction.update(_firestore.collection('users').doc(winnerId), {'balance': FieldValue.increment(totalWin)});
      }
    } else if (ruleType == 'sacrifice') {
      String lastPersonId = room.players.firstWhere((p) => !winners.contains(p));

      if (room.players.length == 2 && winners.length >= 1) {
        payouts[winners[0]] = bet;
        payouts[lastPersonId] = -bet;
        if (!winners[0].startsWith('bot_')) transaction.update(_firestore.collection('users').doc(winners[0]), {'balance': FieldValue.increment(bet)});
        if (!lastPersonId.startsWith('bot_')) transaction.update(_firestore.collection('users').doc(lastPersonId), {'balance': FieldValue.increment(-bet)});
      } else if (room.players.length == 3 && winners.length >= 2) {
        int payout1 = (bet * 0.7).round();
        int payout2 = (bet * 0.3).round();
        payouts[winners[0]] = payout1;
        payouts[winners[1]] = payout2;
        payouts[lastPersonId] = -bet;
        if (!winners[0].startsWith('bot_')) transaction.update(_firestore.collection('users').doc(winners[0]), {'balance': FieldValue.increment(payout1)});
        if (!winners[1].startsWith('bot_')) transaction.update(_firestore.collection('users').doc(winners[1]), {'balance': FieldValue.increment(payout2)});
        if (!lastPersonId.startsWith('bot_')) transaction.update(_firestore.collection('users').doc(lastPersonId), {'balance': FieldValue.increment(-bet)});
      } else if (room.players.length == 4 && winners.length >= 3) {
        int payout1 = bet;
        int payout2 = (bet * 0.5).round();
        int payout3 = -(bet * 0.5).round();
        payouts[winners[0]] = payout1;
        payouts[winners[1]] = payout2;
        payouts[winners[2]] = payout3;
        payouts[lastPersonId] = -bet;
        if (!winners[0].startsWith('bot_')) transaction.update(_firestore.collection('users').doc(winners[0]), {'balance': FieldValue.increment(payout1)});
        if (!winners[1].startsWith('bot_')) transaction.update(_firestore.collection('users').doc(winners[1]), {'balance': FieldValue.increment(payout2)});
        if (!winners[2].startsWith('bot_')) transaction.update(_firestore.collection('users').doc(winners[2]), {'balance': FieldValue.increment(payout3)});
        if (!lastPersonId.startsWith('bot_')) transaction.update(_firestore.collection('users').doc(lastPersonId), {'balance': FieldValue.increment(-bet)});
      }
    }
    // Cập nhật số dư cho Bot trong tài liệu phòng
    Map<String, int> newBotBalances = Map.from(room.botBalances);
    payouts.forEach((pid, amount) {
      if (pid.startsWith('bot_')) {
        newBotBalances[pid] = (newBotBalances[pid] ?? 100000000) + amount;
      }
    });
    transaction.update(_firestore.collection('rooms').doc(room.id), {
      'botBalances': newBotBalances,
    });

    return payouts;
  }

  Future<void> playAgain(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (!doc.exists) return;
      final players = List<String>.from(doc.data()?['players'] ?? []);
      final bots = players.where((p) => p.startsWith('bot_')).toList();

      await _firestore.collection('rooms').doc(roomId).update({
        'status': 'waiting',
        'gameState': null,
        'readyPlayers': bots,
      });
    } catch (e) {}
  }

  Future<void> updateBetAmount(String roomId, int newAmount) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (!doc.exists) return;
      final players = List<String>.from(doc.data()?['players'] ?? []);
      final bots = players.where((p) => p.startsWith('bot_')).toList();

      await _firestore.collection('rooms').doc(roomId).update({
        'betAmount': newAmount,
        'readyPlayers': bots,
      });
    } catch (e) {}
  }

  Future<void> passTurn(String roomId, String userId) async {
    try {
      DocumentReference roomRef = _firestore.collection('rooms').doc(roomId);
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(roomRef);
        if (!snapshot.exists) return;
        RoomModel room = RoomModel.fromMap(snapshot.data() as Map<String, dynamic>, snapshot.id);
        if (room.gameState?.currentTurnId != userId) return;

        List<String> passed = List<String>.from(room.gameState!.passedPlayers);
        if (!passed.contains(userId)) passed.add(userId);

        List<String> activePlayers = room.players.where((p) => (room.gameState!.playerHands[p]?.length ?? 0) > 0).toList();
        
        if (passed.length >= activePlayers.length - 1) {
          String roundWinner = room.gameState!.lastPlayerId ?? userId;
          // Đảm bảo roundWinner là người còn bài (chưa về đích)
          bool winnerHasCards = (room.gameState!.playerHands[roundWinner]?.length ?? 0) > 0;
          if (!winnerHasCards) {
            roundWinner = _getNextActivePlayer(room.players, roundWinner, [...passed, ...room.gameState!.winners]);
          }
          transaction.update(roomRef, {
            'gameState.passedPlayers': [],
            'gameState.lastPlayedCards': [],
            'gameState.lastPlayerId': null,
            'gameState.currentTurnId': roundWinner,
            'gameState.turnStartedAt': FieldValue.serverTimestamp(),
            'gameState.lastPenalty': 0,
          }); 
        } else {
          String nextId = _getNextActivePlayer(room.players, userId, [...passed, ...room.gameState!.winners]);
          transaction.update(roomRef, {
            'gameState.passedPlayers': passed,
            'gameState.currentTurnId': nextId,
            'gameState.turnStartedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {}
  }

  int _applyChopPenalty(Transaction transaction, RoomModel room, String currentId, String victimId, List<CardModel> currentCards) {
    List<CardModel> lastCards = room.gameState!.lastPlayedCards;
    HandResult last = TienLenLogic.analyzeHand(lastCards);
    HandResult current = TienLenLogic.analyzeHand(currentCards);
    int bet = room.betAmount;
    double ratio = 0;

    // Nếu cùng loại + cùng length → chỉ là đánh lớn hơn, KHÔNG PHẠT
    if (current.type == last.type && current.length == last.length) {
      return 0;
    }

    // Chặt heo đơn (single 2) bằng tứ quý / 3 đôi thông / 4 đôi thông
    if (last.type == HandType.single && last.highestCard.rank == CardRank.two) {
      bool isRed = last.highestCard.suit == CardSuit.diamond || last.highestCard.suit == CardSuit.heart;
      ratio = isRed ? 1.0 : 0.5;
    }
    // Chặt đôi heo (pair of 2s) bằng tứ quý / 4 đôi thông
    else if (last.type == HandType.pair && last.highestCard.rank == CardRank.two) {
      int redCount = lastCards.where((c) => c.suit == CardSuit.diamond || c.suit == CardSuit.heart).length;
      if (redCount == 2) ratio = 2.0;
      else if (redCount == 1) ratio = 1.5;
      else ratio = 1.0;
    }
    // Chặt tứ quý bằng 4 đôi thông
    else if (last.type == HandType.fourOfAKind && current.type == HandType.fourDoubleSequence) {
      ratio = 2.0;
    }
    // Chặt 3 đôi thông bằng tứ quý hoặc 4 đôi thông
    else if (last.type == HandType.threeDoubleSequence &&
             (current.type == HandType.fourOfAKind || current.type == HandType.fourDoubleSequence)) {
      ratio = 2.0;
    }
    else {
      // Không phải trường hợp chặt → KHÔNG PHẠT
      return 0;
    }

    int penalty = (bet * ratio).round();
    // Chặt chồng chặt → nhân đôi
    if (room.gameState!.lastPenalty > 0) penalty = room.gameState!.lastPenalty * 2;

    if (penalty > 0) {
      transaction.update(_firestore.collection('users').doc(victimId), {'balance': FieldValue.increment(-penalty)});
      transaction.update(_firestore.collection('users').doc(currentId), {'balance': FieldValue.increment(penalty)});
    }
    return penalty;
  }

  String _getNextActivePlayer(List<String> players, String current, List<String> passed) {
    int idx = players.indexOf(current);
    for (int i = 1; i < players.length; i++) {
      String next = players[(idx + i) % players.length];
      if (!passed.contains(next)) return next;
    }
    return current;
  }

  Stream<RoomModel?> streamRoom(String roomId) {
    return _firestore.collection('rooms').doc(roomId).snapshots().map((doc) => doc.exists ? RoomModel.fromMap(doc.data() as Map<String, dynamic>, doc.id) : null);
  }

  Future<String?> addBot(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (!doc.exists) return "Phòng không tồn tại";
      final players = List<String>.from(doc.data()?['players'] ?? []);
      if (players.length >= 4) return "Phòng đã đầy";

      // Bot ID simple format
      final botId = 'bot_${DateTime.now().millisecondsSinceEpoch}';
      players.add(botId);
      
      final readyPlayers = List<String>.from(doc.data()?['readyPlayers'] ?? []);
      if (!readyPlayers.contains(botId)) readyPlayers.add(botId);

      final botBalances = Map<String, int>.from(doc.data()?['botBalances'] ?? {});
      botBalances[botId] = 100000000; // 100 Triệu vàng

      await _firestore.collection('rooms').doc(roomId).update({
        'players': players,
        'readyPlayers': readyPlayers,
        'botBalances': botBalances,
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> sendInvite(String fromUid, String fromName, String toUid, String roomId, int betAmount) async {
    try {
      // 1. Lưu vào Firestore để hiện In-app Notification
      final inviteDoc = await _firestore.collection('invites').add({
        'fromUid': fromUid,
        'fromName': fromName,
        'toUid': toUid,
        'roomId': roomId,
        'betAmount': betAmount,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Gửi Push Notification cho người Offline
      final userDoc = await _firestore.collection('users').doc(toUid).get();
      final String? fcmToken = userDoc.data()?['fcmToken'];
      
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await NotificationService.sendPushNotification(
          fcmToken,
          'Mời chơi Tiến Lên!',
          '$fromName mời bạn vào bàn cược $betAmount đ. Tham gia ngay!',
          roomId: roomId,
          inviteId: inviteDoc.id,
          type: 'game_invite'
        );
      }
    } catch (e) {
      print('Lỗi gửi lời mời: $e');
    }
  }

  Stream<List<RoomModel>> streamWaitingRooms() {
    return _firestore.collection('rooms')
        .where('status', whereIn: ['waiting', 'playing'])
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map((d) => RoomModel.fromMap(d.data(), d.id)).toList());
  }
}
