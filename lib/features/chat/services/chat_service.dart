import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import '../../../core/services/notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of chat rooms for a user
  Stream<List<ChatModel>> getChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Stream of messages for a specific chat
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Send a message
  Future<void> sendMessage(String chatId, String senderId, String text) async {
    final otherUserId = await _getOtherUserId(chatId, senderId);
    
    final messageData = MessageModel(
      id: '',
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
    ).toMap();

    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    
    batch.set(messageRef, messageData);
    
    batch.update(_firestore.collection('chats').doc(chatId), {
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadBy': otherUserId != null ? FieldValue.arrayUnion([otherUserId]) : [],
    });

    await batch.commit();

    // Gửi thông báo qua Firebase Cloud Messaging (FCM)
    try {
      if (otherUserId != null) {
        // Lấy Token của người nhận
        final receiverDoc = await _firestore.collection('users').doc(otherUserId).get();
        final fcmToken = receiverDoc.data()?['fcmToken'];

        if (fcmToken != null && fcmToken.isNotEmpty) {
          final senderDoc = await _firestore.collection('users').doc(senderId).get();
          final senderName = senderDoc.data()?['displayName'] ?? 'Người thân';

          await NotificationService.sendPushNotification(
            fcmToken,
            "Tin nhắn mới từ $senderName",
            text,
            chatId: chatId,
            otherUserName: senderName, // Tên người gửi
            otherUserId: senderId,     // ID người gửi
          );
        } else {
          print("⚠️ Người nhận chưa có FCM Token");
        }
      }
    } catch (e) {
      print("❌ Lỗi gửi thông báo FCM: $e");
    }
  }

  Future<String?> _getOtherUserId(String chatId, String senderId) async {
    final doc = await _firestore.collection('chats').doc(chatId).get();
    if (doc.exists) {
      List participants = doc['participants'];
      return participants.firstWhere((id) => id != senderId, orElse: () => null);
    }
    return null;
  }

  // Create or get a 1-on-1 chat
  Future<String> getOrCreateChat(String user1, String user2) async {
    final query = await _firestore
        .collection('chats')
        .where('isGroup', isEqualTo: false)
        .where('participants', arrayContains: user1)
        .get();

    for (var doc in query.docs) {
      List participants = doc['participants'];
      if (participants.contains(user2)) {
        return doc.id;
      }
    }

    // Create new chat
    final newChat = await _firestore.collection('chats').add({
      'participants': [user1, user2],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'isGroup': false,
    });

    return newChat.id;
  }

  // Mark a chat as read by a user
  Future<void> markAsRead(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'unreadBy': FieldValue.arrayRemove([userId]),
    });
  }
}
