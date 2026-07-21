import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/draw_guess/draw_room_model.dart';
import '../../models/draw_guess/stroke_model.dart';
import '../../models/draw_guess/draw_message_model.dart';

class DrawGuessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- ROOM MANAGEMENT ---
  Stream<List<DrawRoomModel>> listenToRooms() {
    return _firestore
        .collection('draw_rooms')
        .where('status', isEqualTo: 'waiting')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DrawRoomModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<DrawRoomModel?> listenRoomState(String roomId) {
    return _firestore.collection('draw_rooms').doc(roomId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DrawRoomModel.fromMap(doc.data()!, doc.id);
    });
  }

  Future<String> createRoom({
    required String hostId,
    required String hostName,
    String? hostAvatar,
    int betAmount = 0,
  }) async {
    final player = DrawPlayerModel(
      uid: hostId,
      displayName: hostName,
      avatarUrl: hostAvatar,
      score: 0,
      hasGuessed: false,
    );

    final roomData = DrawRoomModel(
      id: '',
      hostId: hostId,
      status: 'waiting',
      players: [player],
      currentRound: 1,
      totalRounds: 3,
      wordChoices: [],
      secretWord: '',
      betAmount: betAmount,
    );

    final docRef = await _firestore.collection('draw_rooms').add(roomData.toMap());
    return docRef.id;
  }

  Future<void> joinRoom(String roomId, DrawPlayerModel player) async {
    await _firestore.collection('draw_rooms').doc(roomId).update({
      'players': FieldValue.arrayUnion([player.toMap()])
    });
  }

  Future<void> leaveRoom(String roomId, String uid) async {
    final doc = await _firestore.collection('draw_rooms').doc(roomId).get();
    if (!doc.exists) return;
    
    final room = DrawRoomModel.fromMap(doc.data()!, doc.id);
    final playerToRemove = room.players.firstWhere((p) => p.uid == uid, orElse: () => DrawPlayerModel(uid: '', displayName: '', score: 0, hasGuessed: false));
    
    if (playerToRemove.uid.isEmpty) return; // Player not found

    if (room.players.length == 1) {
      // Last player leaving, delete room
      await _firestore.collection('draw_rooms').doc(roomId).delete();
    } else {
      await _firestore.collection('draw_rooms').doc(roomId).update({
        'players': FieldValue.arrayRemove([playerToRemove.toMap()]),
      });
      // Handle if host leaves -> reassign host
      if (room.hostId == uid) {
        final newHost = room.players.firstWhere((p) => p.uid != uid);
        await _firestore.collection('draw_rooms').doc(roomId).update({
          'hostId': newHost.uid
        });
      }
    }
  }

  Future<void> updateRoomStatus(String roomId, String status) async {
    await _firestore.collection('draw_rooms').doc(roomId).update({'status': status});
  }

  Future<void> updateRoom(String roomId, Map<String, dynamic> data) async {
    await _firestore.collection('draw_rooms').doc(roomId).update(data);
  }

  // --- STROKE MANAGEMENT ---
  Stream<List<StrokeModel>> listenStrokes(String roomId) {
    return _firestore
        .collection('draw_rooms')
        .doc(roomId)
        .collection('strokes')
        .snapshots()
        .map((snapshot) {
          // You might want to order by a timestamp if needed, but for now we just load all
          return snapshot.docs
              .map((doc) => StrokeModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Future<void> saveStroke(String roomId, StrokeModel stroke) async {
    await _firestore
        .collection('draw_rooms')
        .doc(roomId)
        .collection('strokes')
        .doc(stroke.id)
        .set(stroke.toMap());
  }

  Future<void> clearCanvas(String roomId) async {
    final batch = _firestore.batch();
    final strokes = await _firestore
        .collection('draw_rooms')
        .doc(roomId)
        .collection('strokes')
        .get();
    
    for (var doc in strokes.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // --- MESSAGE MANAGEMENT ---
  Stream<List<DrawMessageModel>> listenMessages(String roomId) {
    return _firestore
        .collection('draw_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DrawMessageModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> sendMessage(String roomId, DrawMessageModel message) async {
    await _firestore
        .collection('draw_rooms')
        .doc(roomId)
        .collection('messages')
        .add(message.toMap());
  }
}
