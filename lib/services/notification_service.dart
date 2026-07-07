import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    // Request permissions
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground notifications setup
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    
    await _localNotifications.initialize(initializationSettings);

    // Khi đang mở App (Online)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _playTingSound();
    });

    // Khi App đang chạy ngầm và nhấn vào thông báo
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });

    // Khi App tắt hẳn và mở lên từ thông báo
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationClick(initialMessage);
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  static void _handleNotificationClick(RemoteMessage message) {
    final type = message.data['type'];
    final chatId = message.data['chatId'];
    final roomId = message.data['roomId'];
    final otherUserId = message.data['otherUserId'];
    final otherUserName = message.data['otherUserName'];
    
    if (type == 'chat' && chatId != null && chatId.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        navigatorKey.currentState?.pushNamed(
          '/chat_detail', 
          arguments: {
            'chatId': chatId,
            'otherUserId': otherUserId ?? '',
            'otherUserName': otherUserName ?? 'Người dùng',
          }
        );
      });
    } else if (type == 'game_invite' && roomId != null && roomId.isNotEmpty) {
      final inviteId = message.data['inviteId'];
      final game = message.data['game'] ?? 'tien_len';

      if (inviteId != null && inviteId.isNotEmpty) {
        FirebaseFirestore.instance.collection('invites').doc(inviteId).update({'status': 'accepted'});
      }
      
      Future.delayed(const Duration(milliseconds: 1000), () async {
        if (game == 'caro') {
          // Lấy user hiện tại
          final uid = FirebaseFirestore.instance.app.options.projectId; // Không an toàn lắm, nhưng NotificationService không có AuthBloc
          // Đợi đã, để lấy currentUserUid, có thể lấy từ AuthService.
          // Nhưng route '/caro_room' cần currentUserUid.
          // Cách an toàn là lấy từ auth Firebase
          // Tuy nhiên, mình có thể truyền empty rồi xử lý sau, hoặc bỏ qua vì GlobalInviteListener (Overlay) đã xử lý tốt.
          // Thật ra, khi click push, user sẽ vào app. Khi vào app, GlobalInviteListener sẽ kích hoạt nếu invite còn pending.
          // Nhưng nếu click từ push, ta vẫn cần đẩy route.
          // Để đơn giản, ta chỉ cần truyền roomId, và sửa route `/caro_room` trong main.dart để nó lấy UID từ AuthBloc nếu không có argument.
          navigatorKey.currentState?.pushNamed(
            '/caro_room',
            arguments: {'roomId': roomId} // Không truyền uid, lát sửa main.dart
          );
        } else {
          navigatorKey.currentState?.pushNamed(
            '/tien_len_room',
            arguments: {'roomId': roomId}
          );
        }
      });
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint("Handling a background message: ${message.messageId}");
  }

  static Future<void> _playTingSound() async {
    try {
      await _audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2358/2358-preview.mp3'));
    } catch (e) {
      debugPrint('Lỗi phát âm thanh ting: $e');
    }
  }

  static Future<void> updateToken(String userId) async {
    String? token = await _fcm.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    }
  }

  static Future<String?> _getAccessToken() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('fcm').get();
      final String? serviceAccountJson = doc.data()?['serviceAccountKey'];

      if (serviceAccountJson == null) return null;

      final accountCredentials = auth.ServiceAccountCredentials.fromJson(serviceAccountJson);
      final scopes = ['https://www.googleapis.com/auth/cloud-platform'];
      
      final client = await auth.clientViaServiceAccount(accountCredentials, scopes);
      final accessToken = client.credentials.accessToken.data;
      client.close();
      
      return accessToken;
    } catch (e) {
      return null;
    }
  }

  static Future<void> sendPushNotification(
    String receiverToken, 
    String title, 
    String body, 
    {String? chatId, String? otherUserId, String? otherUserName, String? roomId, String? inviteId, String type = 'chat', String? game}
  ) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) return;

      final doc = await FirebaseFirestore.instance.collection('settings').doc('fcm').get();
      final String serviceAccountJson = doc.data()?['serviceAccountKey'] ?? '';
      final Map<String, dynamic> accountData = jsonDecode(serviceAccountJson);
      final String projectId = accountData['project_id'];

      final String fcmUrl = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final msg = {
        "message": {
          "token": receiverToken,
          "notification": {
            "title": title,
            "body": body
          },
          "android": {
            "priority": "high",
            "notification": {
              "sound": "default",
              "channel_id": "chat_messages",
              "notification_priority": "PRIORITY_MAX"
            }
          },
          "apns": {
            "payload": {
              "aps": {
                "sound": "default",
                "badge": 1
              }
            }
          },
          "data": {
            "type": type,
            "game": game ?? "tien_len",
            "title": title,
            "body": body,
            "chatId": chatId ?? "",
            "roomId": roomId ?? "",
            "inviteId": inviteId ?? "",
            "otherUserId": otherUserId ?? "",
            "otherUserName": otherUserName ?? ""
          }
        }
      };

      await http.post(
        Uri.parse(fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(msg),
      );
    } catch (e) {
      debugPrint('❌ Lỗi gửi push: $e');
    }
  }
}
