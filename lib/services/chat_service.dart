import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phan_family/models/chat_model.dart';
import '../models/message_model.dart';
import 'notification_service.dart';

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

  // Upload a media file to Cloudinary
  Future<String> uploadMediaFile({
    required String chatId,
    required File file,
    required String mediaType, // 'image', 'video', 'audio'
    required String fileName,
  }) async {
    try {
      if (!await file.exists()) {
        throw Exception('File không tồn tại: ${file.path}');
      }

      final String cloudName = 'dogxxj74b';
      final String uploadPreset = 'ml_default';
      
      // Cloudinary gộp chung video và audio vào resource_type là 'video'
      String resourceType = mediaType == 'image' ? 'image' : 'video';
      
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');
      
      var request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseData);
        return jsonResponse['secure_url']; // URL https trả về từ Cloudinary
      } else {
        var responseData = await response.stream.bytesToString();
        print('❌ Lỗi Cloudinary: ${response.statusCode} - $responseData');
        throw Exception('Không thể tải file lên Cloudinary');
      }
    } catch (e) {
      print('❌ Upload error: $e');
      rethrow;
    }
  }

  // Send a message
  Future<void> sendMessage(
    String chatId,
    String senderId,
    String text, {
    MessageType type = MessageType.text,
    int? duration,
  }) async {
    final otherUserId = await _getOtherUserId(chatId, senderId);
    
    final messageData = MessageModel(
      id: '',
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
      type: type,
      duration: duration,
    ).toMap();

    final batch = _firestore.batch();

    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    
    batch.set(messageRef, messageData);
    
    String lastMsgText = text;
    if (type == MessageType.image) {
      lastMsgText = '📷 [Hình ảnh]';
    } else if (type == MessageType.video) {
      lastMsgText = '🎥 [Video]';
    } else if (type == MessageType.audio) {
      lastMsgText = '🎙️ [Tin nhắn thoại]';
    } else if (type == MessageType.gif) {
      lastMsgText = '👾 [GIF]';
    }

    batch.update(_firestore.collection('chats').doc(chatId), {
      'lastMessage': lastMsgText,
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

          String notificationBody = text;
          if (type == MessageType.image) {
            notificationBody = "Đã gửi một ảnh";
          } else if (type == MessageType.video) {
            notificationBody = "Đã gửi một video";
          } else if (type == MessageType.audio) {
            notificationBody = "Đã gửi một tin nhắn thoại";
          } else if (type == MessageType.gif) {
            notificationBody = "Đã gửi một GIF";
          }

          await NotificationService.sendPushNotification(
            fcmToken,
            "Tin nhắn mới từ $senderName",
            notificationBody,
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

  // Update chat theme
  Future<void> updateChatTheme(String chatId, {String? backgroundImage}) async {
    final Map<String, dynamic> updates = {};
    if (backgroundImage != null) updates['backgroundImage'] = backgroundImage;
    
    if (updates.isNotEmpty) {
      await _firestore.collection('chats').doc(chatId).update(updates);
    }
  }

  // Mark a chat as read by a user
  Future<void> markAsRead(String chatId, String userId) async {
    await _firestore.collection('chats').doc(chatId).update({
      'unreadBy': FieldValue.arrayRemove([userId]),
    });
  }
}
