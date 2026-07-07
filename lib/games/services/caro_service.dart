import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/caro_model.dart';


class CaroService {
  final FirebaseFirestore firestore =  FirebaseFirestore.instance;

  CollectionReference get roomRef =>
      firestore.collection('rooms');

  CollectionReference get usersRef =>
      firestore.collection('users');

  /// Lưu roomId đang chơi dở vào profile user
  Future<void> saveActiveRoom({required String uid, required String roomId}) async {
    await usersRef.doc(uid).update({'activeRoomId': roomId});
  }

  /// Xóa activeRoomId khi ván kết thúc hoặc thoát hẳn
  Future<void> clearActiveRoom({required String uid}) async {
    await usersRef.doc(uid).update({'activeRoomId': null});
  }

  /// Lấy thông tin room đang dở của user (nếu có)
  Future<CaroModel?> getActiveRoom({required String uid}) async {
    final userDoc = await usersRef.doc(uid).get();
    final data = userDoc.data() as Map<String, dynamic>?;
    final roomId = data?['activeRoomId'] as String?;
    if (roomId == null || roomId.isEmpty) return null;

    final roomDoc = await roomRef.doc(roomId).get();
    if (!roomDoc.exists) return null;

    final roomData = roomDoc.data() as Map<String, dynamic>?;
    if (roomData == null) return null;

    // Only return if this is a Caro room
    if (roomData['roomType'] != 'caro') return null;

    // Only return if game is not finished
    if (roomData['winner'] != 0) return null;

    return CaroModel.fromJson(roomData);
  }

  Stream<CaroModel> roomStream(
      String roomId,
      )
  {
    return roomRef
        .doc(roomId)
        .snapshots()
        .map(
          (e) => CaroModel.fromJson(
        e.data() as Map<String, dynamic>,
      ),
    );
  }

  Future<String> createRoom({
    required String hostId,
    required String hostName,
  }) async {

    String roomId =
    Random()
        .nextInt(999999)
        .toString()
        .padLeft(6, '0');

    List<List<int>> board =
    List.generate(
      15,
          (_) => List.filled(15, 0),
    );

    await firestore
        .collection('rooms')
        .doc(roomId)
        .set({
      "roomId": roomId,
      "roomType": "caro", // Tag this as a Caro room
      "hostId": hostId,
      "hostName": hostName,
      "guestId": "",
      "guestName": "",
      "turn": 1,
      "winner": 0,
      "status": "waiting",
      "board": CaroModel.boardToFlat(board), // flat 1D - Firestore không hỗ trợ nested arrays
      "createdAt":
      FieldValue.serverTimestamp(),
    });

    // Lưu activeRoom vào user document
    await saveActiveRoom(uid: hostId, roomId: roomId);

    return roomId;
  }

  Future<void> joinRoom({
    required String roomId,
    required String uid,
    required String name,
  }) async {

    await firestore
        .collection('rooms')
        .doc(roomId)
        .update({
      "guestId": uid,
      "guestName": name,
      "status": "playing",
    });

    // Lưu activeRoom vào user document
    await saveActiveRoom(uid: uid, roomId: roomId);
  }
}
