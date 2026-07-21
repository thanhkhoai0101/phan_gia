import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:phan_family/services/cloudinary_service.dart';
import 'package:phan_family/models/chat_model.dart';
import '../models/message_model.dart';
import 'notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final Map<String, List<String>> _dictionary = {};
  static bool _dictionaryLoaded = false;

  Future<void> _loadDictionaryIfNeeded() async {
    if (_dictionaryLoaded) return;
    try {
      final content = await rootBundle.loadString('assets/words/vietnamese_words.txt');
      final lines = content.split('\n');
      for (var line in lines) {
        final word = line.trim().toLowerCase();
        if (word.isEmpty) continue;
        
        final parts = word.split(RegExp(r'\s+'));
        if (parts.length != 2) continue;
        
        // Remove words with numbers or special chars
        if (word.contains(RegExp(r'[0-9\-_@#\$%\^&\*\(\)\+=\{\}\[\]\|\\:;"<>\?,\./]'))) {
          continue;
        }

        final firstSyllable = parts[0];
        _dictionary.putIfAbsent(firstSyllable, () => []).add(word);
      }
      _dictionaryLoaded = true;
      print('✅ Đã nạp thành công từ điển tiếng Việt: ${_dictionary.length} âm đầu.');
    } catch (e) {
      print('❌ Lỗi nạp từ điển tiếng Việt: $e');
    }
  }

  Future<String> _getRandomWord() async {
    await _loadDictionaryIfNeeded();
    if (_dictionary.isEmpty) return "vui vẻ";
    final keys = _dictionary.keys.toList();
    final randomKey = keys[Random().nextInt(keys.length)];
    final words = _dictionary[randomKey]!;
    return words[Random().nextInt(words.length)];
  }

  Future<String?> _getBotResponse(String nextSyllable, List<String> playedWords) async {
    await _loadDictionaryIfNeeded();
    final words = _dictionary[nextSyllable.toLowerCase()];
    if (words == null || words.isEmpty) return null;
    
    final availableWords = words.where((w) => !playedWords.contains(w)).toList();
    if (availableWords.isEmpty) return null;
    
    return availableWords[Random().nextInt(availableWords.length)];
  }

  void _triggerBotPlay(String chatId, String nextSyllable, List<String> playedWords) {
    Future.delayed(const Duration(milliseconds: 1500), () async {
      final botWord = await _getBotResponse(nextSyllable, playedWords);
      if (botWord != null) {
        final parts = botWord.split(RegExp(r'\s+'));
        final botNextSyllable = parts[1];
        
        await _firestore.collection('chats').doc(chatId).update({
          'wordChain.lastWord': botWord,
          'wordChain.nextSyllable': botNextSyllable,
          'wordChain.wordsPlayed': FieldValue.arrayUnion([botWord]),
          'wordChain.lastPlayerId': 'bot_noitu',
        });
        
        await sendMessage(chatId, 'bot_noitu', botWord);
      } else {
        await _firestore.collection('chats').doc(chatId).update({
          'wordChain.active': false,
        });
        await sendMessage(chatId, 'bot_noitu', "🏆 Bot không tìm được từ nào tiếp theo bắt đầu bằng '**$nextSyllable**'! Các bạn đã thắng cuộc!");
      }
    });
  }

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
    final CloudinaryService cloudinary = CloudinaryService();
    final url = await cloudinary.uploadMediaFile(file, mediaType: mediaType);
    if (url != null) {
      return url;
    } else {
      throw Exception('Không thể tải file lên Cloudinary');
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
    // 1. Fetch chat document to get participants and game state
    final doc = await _firestore.collection('chats').doc(chatId).get();
    List<String> participants = [];
    bool isGroup = false;
    Map<String, dynamic>? wordChain;
    
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      participants = List<String>.from(data['participants'] ?? []);
      isGroup = data['isGroup'] ?? false;
      wordChain = data['wordChain'] as Map<String, dynamic>?;
    }
    
    // Get all receivers (except sender and the bot itself)
    final recips = participants.where((id) => id != senderId && id != 'bot_noitu').toList();

    // 2. Save the user message to Firestore
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
      'unreadBy': recips.isNotEmpty ? FieldValue.arrayUnion(recips) : [],
    });

    await batch.commit();

    // 3. Send Push Notifications via FCM
    try {
      for (var otherUserId in recips) {
        final receiverDoc = await _firestore.collection('users').doc(otherUserId).get();
        if (!receiverDoc.exists) continue;
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
            isGroup ? "Tin nhắn mới từ nhóm" : "Tin nhắn mới từ $senderName",
            notificationBody,
            chatId: chatId,
            otherUserName: senderName,
            otherUserId: senderId,
          );
        }
      }
    } catch (e) {
      print("❌ Lỗi gửi thông báo FCM: $e");
    }

    // 4. Game logic for Word Chaining (Đối Từ)
    if (senderId != 'bot_noitu' && type == MessageType.text) {
      final cleanText = text.trim().toLowerCase();
      
      // Start Command
      if (cleanText == '!noitu') {
        final startingWord = await _getRandomWord();
        final parts = startingWord.split(RegExp(r'\s+'));
        final nextSyllable = parts[1];
        
        await _firestore.collection('chats').doc(chatId).update({
          'wordChain': {
            'active': true,
            'lastWord': startingWord,
            'nextSyllable': nextSyllable,
            'wordsPlayed': [startingWord],
            'lastPlayerId': 'bot_noitu',
          }
        });
        
        // Let the bot announce the start
        await sendMessage(
          chatId, 
          'bot_noitu', 
          "🎮 **Trò chơi Nối Từ bắt đầu!**\nTừ khởi đầu: **$startingWord**.\nHãy nối tiếp từ bắt đầu bằng chữ '**$nextSyllable**'!"
        );
        return;
      }
      
      // Stop Command
      if (cleanText == '!stop') {
        if (wordChain != null && wordChain['active'] == true) {
          await _firestore.collection('chats').doc(chatId).update({
            'wordChain.active': false,
          });
          await sendMessage(chatId, 'bot_noitu', "⏹️ **Đã dừng trò chơi Nối Từ.**");
        }
        return;
      }
      
      // Game Play validation
      if (wordChain != null && wordChain['active'] == true) {
        final parts = cleanText.split(RegExp(r'\s+'));
        final expectedSyllable = (wordChain['nextSyllable'] as String).toLowerCase();
        
        // If it's a 2-syllable word starting with the expected syllable
        if (parts.length == 2 && parts[0] == expectedSyllable) {
          await _loadDictionaryIfNeeded();
          
          final exists = _dictionary[parts[0]]?.contains(cleanText) == true;
          if (exists) {
            final wordsPlayed = List<String>.from(wordChain['wordsPlayed'] ?? []);
            
            if (wordsPlayed.contains(cleanText)) {
              await sendMessage(
                chatId, 
                'bot_noitu', 
                "❌ Từ '**$text**' đã được dùng rồi! Hãy tìm từ khác bắt đầu bằng '**$expectedSyllable**'."
              );
            } else {
              // Valid play! Update game state
              final nextSyllable = parts[1];
              await _firestore.collection('chats').doc(chatId).update({
                'wordChain.lastWord': cleanText,
                'wordChain.nextSyllable': nextSyllable,
                'wordChain.wordsPlayed': FieldValue.arrayUnion([cleanText]),
                'wordChain.lastPlayerId': senderId,
              });
              
              // Trigger Bot response
              _triggerBotPlay(chatId, nextSyllable, [...wordsPlayed, cleanText]);
            }
          } else {
            // Syllable matches but not in dictionary
            await sendMessage(
              chatId, 
              'bot_noitu', 
              "❌ Từ '**$text**' không có trong từ điển! Hãy tìm từ khác bắt đầu bằng '**$expectedSyllable**'."
            );
          }
        }
      }
    }
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
  Future<void> updateChatTheme(String chatId, {String? backgroundImage, String? bubbleStyle}) async {
    final Map<String, dynamic> updates = {};
    if (backgroundImage != null) updates['backgroundImage'] = backgroundImage;
    if (bubbleStyle != null) updates['bubbleStyle'] = bubbleStyle;
    
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

  // Create a new group chat
  Future<String> createGroupChat({
    required String creatorId,
    required String groupName,
    required List<String> memberIds,
    required bool addBot,
  }) async {
    final participants = [creatorId, ...memberIds];
    if (addBot && !participants.contains('bot_noitu')) {
      participants.add('bot_noitu');
    }
    
    final newChat = await _firestore.collection('chats').add({
      'participants': participants,
      'lastMessage': 'Nhóm đã được tạo',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'isGroup': true,
      'groupName': groupName,
      'unreadBy': [],
    });
    
    return newChat.id;
  }
}
