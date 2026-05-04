import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import 'features/auth/services/auth_service.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/bloc/auth_state.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/chat/screens/chat_detail_screen.dart';
import 'features/games/tien_len/screens/tien_len_room_screen.dart';
import 'features/main_nav/main_nav_screen.dart';
import 'core/services/notification_service.dart';
import 'core/models/user_model.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Firebase/Notification init error: $e');
  }

  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(NotificationService.navigatorKey);

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (context) => AuthBloc(authService: AuthService())),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  void onUserLogin(UserModel user) {
    NotificationService.updateToken(user.uid);
    ZegoUIKitPrebuiltCallInvitationService().init(
      appID: 412261045,
      appSign: '056c2a653b08645f7604a20598e6a15abd17d7b39e272235609ba06e0aec06ac',
      userID: user.uid,
      userName: user.displayName,
      plugins: [ZegoUIKitSignalingPlugin()],
      notificationConfig: ZegoCallInvitationNotificationConfig(
        androidNotificationConfig: ZegoCallAndroidNotificationConfig(
          callChannel: ZegoCallAndroidNotificationChannelConfig(
            channelID: "ZegoUIKit",
            channelName: "Call Notifications",
            sound: "call",
            icon: "launcher_icon",
          ),
        ),
        iOSNotificationConfig: ZegoCallIOSNotificationConfig(
          isSandboxEnvironment: false,
        ),
      ),
      requireConfig: (ZegoCallInvitationData data) {
        final config = (data.type == ZegoCallInvitationType.videoCall)
            ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
            : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();
        return config;
      },
    );
  }

  void onUserLogout() {
    ZegoUIKitPrebuiltCallInvitationService().uninit();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          onUserLogin(state.user);
        } else if (state is AuthUnauthenticated) {
          onUserLogout();
        }
      },
      child: MaterialApp(
        navigatorKey: NotificationService.navigatorKey,
        title: 'Phan Gia',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF1A374D),
          scaffoldBackgroundColor: const Color(0xFF0F1B2A),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A374D),
            brightness: Brightness.dark,
            primary: const Color(0xFF1A374D),
            secondary: const Color(0xFFFF6B6B),
            surface: const Color(0xFF162435),
            surfaceContainerHigh: const Color(0xFF0F1B2A),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xFF162435),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF1A2A3A),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: Colors.white10,
            selectedColor: const Color(0xFFFF6B6B),
            labelStyle: const TextStyle(color: Colors.white),
            secondaryLabelStyle: const TextStyle(color: Colors.white),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0F1B2A),
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        builder: (context, child) {
          return GlobalInviteListener(child: child!);
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/chat_detail') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                chatId: args['chatId'],
                otherUserName: args['otherUserName'],
                otherUserId: args['otherUserId'],
              ),
            );
          } else if (settings.name == '/tien_len_room') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => TienLenRoomScreen(roomId: args['roomId']),
            );
          }
          return null;
        },
        home: BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (previous, current) => previous.runtimeType != current.runtimeType,
          builder: (context, state) {
            if (state is AuthAuthenticated) {
              return const MainNavScreen();
            }
            if (state is AuthInitial || state is AuthLoading) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

class GlobalInviteListener extends StatelessWidget {
  final Widget child;
  const GlobalInviteListener({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) return child;
        final user = state.user;

        return Stack(
          children: [
            child,
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('invites')
                  .where('toUid', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
                final invites = snapshot.data!.docs;
                invites.sort((a, b) {
                  final ta = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                  final tb = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                  if (ta == null) return -1;
                  if (tb == null) return 1;
                  return tb.compareTo(ta);
                });
                
                final inviteDoc = invites.first;
                final data = inviteDoc.data() as Map<String, dynamic>;
                
                return _buildInviteOverlay(context, inviteDoc.id, data);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildInviteOverlay(BuildContext context, String inviteId, Map<String, dynamic> data) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1B4D3E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amberAccent, width: 2),
            boxShadow: [BoxShadow(color: Colors.amberAccent.withOpacity(0.3), blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videogame_asset, color: Colors.amberAccent, size: 40),
              const SizedBox(height: 15),
              Text('${data['fromName']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const Text('mời bạn chơi Tiến Lên!', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 10),
              Text('Cược: ${data['betAmount']} đ', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => FirebaseFirestore.instance.collection('invites').doc(inviteId).update({'status': 'declined'}),
                    child: const Text('TỪ CHỐI', style: TextStyle(color: Colors.white54)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance.collection('invites').doc(inviteId).update({'status': 'accepted'});
                      NotificationService.navigatorKey.currentState?.pushNamed(
                        '/tien_len_room',
                        arguments: {'roomId': data['roomId']}
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
                    child: const Text('THAM GIA'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
