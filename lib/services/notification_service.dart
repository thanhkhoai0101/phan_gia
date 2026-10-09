import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:audioplayers/audioplayers.dart';
import '../games/services/caro_service.dart';

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

    // Foreground notifications setup & Android Notification Channel
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    
    await _localNotifications.initialize(initializationSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Kênh thông báo tin nhắn và lời mời trò chơi',
      importance: Importance.max,
      playSound: true,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(channel);
      await androidPlugin.requestNotificationsPermission();
    }

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

  /// Lấy thông tin user hiện tại từ Firebase Auth
  static User? _getCurrentFirebaseUser() {
    return FirebaseAuth.instance.currentUser;
  }

  /// Lấy displayName từ Firestore (chính xác hơn Firebase Auth)
  static Future<String> _getDisplayNameFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      final name = data?['displayName'] as String?;
      if (name != null && name.isNotEmpty) return name;
    } catch (e) {
      debugPrint('Lỗi lấy displayName từ Firestore: $e');
    }
    return 'Người chơi';
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
          },
        );
      });
    } else if (type == 'game_invite' && roomId != null && roomId.isNotEmpty) {
      final inviteId = message.data['inviteId'];
      final game = message.data['game'] ?? 'tien_len';

      Future.delayed(const Duration(milliseconds: 1000), () async {
        // Lấy user hiện tại từ Firebase Auth
        final firebaseUser = _getCurrentFirebaseUser();
        final currentUid = firebaseUser?.uid ?? '';
        // Lấy tên từ Firestore vì Firebase Auth displayName thường bị rỗng
        final currentName = currentUid.isNotEmpty
            ? await _getDisplayNameFromFirestore(currentUid)
            : 'Người chơi';

        // Accept invite trong Firestore
        if (inviteId != null && inviteId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('invites')
              .doc(inviteId)
              .update({'status': 'accepted'});
        }

        if (game == 'caro') {
          // Join phòng Caro để cập nhật guestId, guestName, status → 'playing'
          if (currentUid.isNotEmpty) {
            try {
              await CaroService().joinRoom(
                roomId: roomId,
                uid: currentUid,
                name: currentName,
              );
            } catch (e) {
              debugPrint('Lỗi joinRoom caro: $e');
            }
          }
          navigatorKey.currentState?.pushNamed(
            '/caro_room',
            arguments: {
              'roomId': roomId,
              'currentUserUid': currentUid,
            },
          );
        } else {
          navigatorKey.currentState?.pushNamed(
            '/tien_len_room',
            arguments: {'roomId': roomId},
          );
        }
      });
    }
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

    _fcm.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'fcmToken': newToken,
      }, SetOptions(merge: true));
    });
  }

  static Future<String?> _getAccessToken() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('fcm').get();
      final String? serviceAccountJson = doc.data()?['serviceAccountKey'];

      if (serviceAccountJson == null) {
        debugPrint('⚠️ Lỗi FCM: Chưa cấu hình serviceAccountKey trong Firestore (collection settings, doc fcm).');
        return null;
      }

      final accountCredentials = auth.ServiceAccountCredentials.fromJson(serviceAccountJson);
      final scopes = ['https://www.googleapis.com/auth/cloud-platform'];
      
      final client = await auth.clientViaServiceAccount(accountCredentials, scopes);
      final accessToken = client.credentials.accessToken.data;
      client.close();
      
      return accessToken;
    } catch (e) {
      debugPrint('❌ Lỗi lấy FCM AccessToken: $e');
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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}
