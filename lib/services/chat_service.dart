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

      // Also load custom words from Firestore
      try {
        final customSnap = await _firestore.collection('custom_words').get();
        for (var doc in customSnap.docs) {
          final word = (doc.data()['word'] as String?)?.trim().toLowerCase();
          if (word == null || word.isEmpty) continue;
          final parts = word.split(RegExp(r'\s+'));
          if (parts.length != 2) continue;
          final firstSyllable = parts[0];
          if (_dictionary[firstSyllable]?.contains(word) != true) {
            _dictionary.putIfAbsent(firstSyllable, () => []).add(word);
          }
        }
      } catch (_) {}

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
      
      // !noitu is now intercepted by the UI — ChatDetailScreen shows a dialog.
      // If somehow it reaches here, ignore it gracefully.
      if (cleanText == '!noitu') return;
      
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

      // !add Command — only khoai@gmail.com can add words
      if (cleanText.startsWith('!add ')) {
        final newWord = cleanText.substring(5).trim().toLowerCase();
        
        // Check permission: only khoai@gmail.com
        String senderEmail = '';
        try {
          final userDoc = await _firestore.collection('users').doc(senderId).get();
          senderEmail = (userDoc.data()?['email'] as String?) ?? '';
        } catch (_) {}

        if (senderEmail != 'khoai@gmail.com') {
          await sendMessage(
            chatId,
            'bot_noitu',
            "🔒 Chỉ tài khoản **admin** mới được thêm từ vào từ điển!",
          );
          return;
        }

        // Validate: must be exactly 2 syllables
        final wordParts = newWord.split(RegExp(r'\s+'));
        if (wordParts.length != 2) {
          await sendMessage(
            chatId,
            'bot_noitu',
            "❌ Từ phải có đúng **2 âm tiết** (ví dụ: `điểm danh`). Bạn đã nhập ${wordParts.length} âm tiết.",
          );
          return;
        }

        // Check if word already exists in dictionary
        await _loadDictionaryIfNeeded();
        final firstSyllable = wordParts[0];
        if (_dictionary[firstSyllable]?.contains(newWord) == true) {
          await sendMessage(
            chatId,
            'bot_noitu',
            "⚠️ Từ '**$newWord**' đã có sẵn trong từ điển rồi!",
          );
          return;
        }

        // Add to in-memory dictionary
        _dictionary.putIfAbsent(firstSyllable, () => []).add(newWord);

        // Persist to Firestore so it survives app restarts
        await _firestore.collection('custom_words').add({
          'word': newWord,
          'addedBy': senderId,
          'addedAt': FieldValue.serverTimestamp(),
        });

        await sendMessage(
          chatId,
          'bot_noitu',
          "✅ Đã thêm từ '**$newWord**' vào từ điển thành công!",
        );
        return;
      }
      
      // Game Play validation
      if (wordChain != null && wordChain['active'] == true) {
        final parts = cleanText.split(RegExp(r'\s+'));
        final expectedSyllable = (wordChain['nextSyllable'] as String).toLowerCase();
        final botPlays = wordChain['botPlays'] == true;
        final int currentFailCount = (wordChain['failCount'] as int?) ?? 0;
        final String lastCorrectPlayerId = (wordChain['lastCorrectPlayerId'] as String?) ?? '';
        final String lastPlayerId = (wordChain['lastPlayerId'] as String?) ?? '';
        const int maxFails = 5;

        // Block the same player from playing two turns in a row
        if (parts.length == 2 && parts[0] == expectedSyllable && senderId == lastPlayerId && lastPlayerId.isNotEmpty) {
          String playerName = senderId;
          try {
            final doc = await _firestore.collection('users').doc(senderId).get();
            playerName = doc.data()?['displayName'] ?? senderId;
          } catch (_) {}
          await sendMessage(
            chatId,
            'bot_noitu',
            "🚫 **$playerName** vừa nối từ rồi! Hãy chờ người khác đi tiếp trước nhé.",
          );
          return;
        }
        
        // Only validate if the word starts with the expected syllable
        if (parts.length == 2 && parts[0] == expectedSyllable) {
          await _loadDictionaryIfNeeded();
          
          final exists = _dictionary[parts[0]]?.contains(cleanText) == true;
          if (exists) {
            final wordsPlayed = List<String>.from(wordChain['wordsPlayed'] ?? []);
            
            if (wordsPlayed.contains(cleanText)) {
              // Wrong: duplicate word — increment fail counter
              final newFailCount = currentFailCount + 1;
              final remaining = maxFails - newFailCount;

              if (newFailCount >= maxFails) {
                // 5 fails reached — end game and announce winner
                await _endGameWithWinner(chatId, lastCorrectPlayerId, expectedSyllable);
              } else {
                await _firestore.collection('chats').doc(chatId).update({
                  'wordChain.failCount': newFailCount,
                });
                await sendMessage(
                  chatId,
                  'bot_noitu',
                  "❌ Từ '**$text**' đã được dùng rồi! Hãy tìm từ khác bắt đầu bằng '**$expectedSyllable**'.\n⚠️ Còn **$remaining** lần thử — trả lời sai thêm sẽ thua!"
                );
              }
            } else {
              // Valid play! Reset fail counter, update last correct player
              final nextSyllable = parts[1];
              await _firestore.collection('chats').doc(chatId).update({
                'wordChain.lastWord': cleanText,
                'wordChain.nextSyllable': nextSyllable,
                'wordChain.wordsPlayed': FieldValue.arrayUnion([cleanText]),
                'wordChain.lastPlayerId': senderId,
                'wordChain.lastCorrectPlayerId': senderId,
                'wordChain.failCount': 0,
              });

              if (botPlays) {
                // Bot plays as a participant — responds with the next word
                _triggerBotPlay(chatId, nextSyllable, [...wordsPlayed, cleanText]);
              } else {
                // Bot is only a referee — just confirm the word is valid
                await sendMessage(
                  chatId,
                  'bot_noitu',
                  "✅ '**$text**' — Hợp lệ! Tiếp theo hãy nối từ bắt đầu bằng '**$nextSyllable**'."
                );
              }
            }
          } else {
            // Wrong: syllable matches but word not in dictionary — increment fail counter
            final newFailCount = currentFailCount + 1;
            final remaining = maxFails - newFailCount;

            if (newFailCount >= maxFails) {
              await _endGameWithWinner(chatId, lastCorrectPlayerId, expectedSyllable);
            } else {
              await _firestore.collection('chats').doc(chatId).update({
                'wordChain.failCount': newFailCount,
              });
              await sendMessage(
                chatId,
                'bot_noitu',
                "❌ Từ '**$text**' không có trong từ điển! Hãy tìm từ khác bắt đầu bằng '**$expectedSyllable**'.\n⚠️ Còn **$remaining** lần thử — trả lời sai thêm sẽ thua!"
              );
            }
          }
        }
      }
    }
  }

  // Start a new Word Chaining game session. Called by the UI after the user
  // selects whether the bot should play as a participant or just referee.
  Future<void> startWordChain(String chatId, String starterId, {required bool botPlays}) async {
    final startingWord = await _getRandomWord();
    final parts = startingWord.split(RegExp(r'\s+'));
    final nextSyllable = parts[1];

    await _firestore.collection('chats').doc(chatId).update({
      'wordChain': {
        'active': true,
        'botPlays': botPlays,
        'lastWord': startingWord,
        'nextSyllable': nextSyllable,
        'wordsPlayed': [startingWord],
        'lastPlayerId': 'bot_noitu',
        'lastCorrectPlayerId': '',
        'failCount': 0,
      }
    });

    final modeLabel = botPlays
        ? "🤖 Bot sẽ **tham gia nối từ** cùng các bạn."
        : "👥 Bot chỉ làm **trọng tài** — kiểm tra từ đúng/sai.";

    await sendMessage(
      chatId,
      'bot_noitu',
      "🎮 **Trò chơi Nối Từ bắt đầu!**\n$modeLabel\nTừ khởi đầu: **$startingWord**.\nHãy nối tiếp từ bắt đầu bằng chữ '**$nextSyllable**'!"
    );
  }

  // End the game and announce winner based on lastCorrectPlayerId.
  Future<void> _endGameWithWinner(String chatId, String winnerId, String syllable) async {
    await _firestore.collection('chats').doc(chatId).update({
      'wordChain.active': false,
    });

    if (winnerId.isEmpty || winnerId == 'bot_noitu') {
      await sendMessage(
        chatId,
        'bot_noitu',
        "⏹️ Đã sai **5 lần liên tiếp** với âm '**$syllable**'. Không có người chiến thắng — hòa!"
      );
    } else {
      // Look up display name of the winner
      String winnerName = winnerId;
      try {
        final doc = await _firestore.collection('users').doc(winnerId).get();
        winnerName = doc.data()?['displayName'] ?? winnerId;
      } catch (_) {}

      await sendMessage(
        chatId,
        'bot_noitu',
        "🏆 **$winnerName** chiến thắng!\nMọi người đã trả lời sai **5 lần liên tiếp** với âm '**$syllable**' — người nối từ đúng cuối cùng là bạn!"
      );
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
