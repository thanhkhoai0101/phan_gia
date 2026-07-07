import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:phan_family/services/auth_service.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_state.dart';
import 'blocs/theme/theme_bloc.dart';
import 'blocs/theme/theme_state.dart';
import 'blocs/feed/feed_bloc.dart';
import 'services/feed_service.dart';
import 'features/auth/login_screen.dart';
import 'features/chat/chat_detail_screen.dart';
import 'games/screens/tien_len/tien_len_room_screen.dart';
import 'features/main_nav/main_nav_screen.dart';
import 'games/screens/caro/caro_screen.dart';
import 'games/blocs/caro/caro_bloc.dart';
import 'games/services/caro_service.dart';
import 'services/notification_service.dart';
import 'models/user_model.dart';
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

  // Load saved theme preference
  final bool isDarkMode = await ThemeBloc.loadSavedDarkMode();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (context) => AuthBloc(authService: AuthService())),
        BlocProvider<ThemeBloc>(create: (context) => ThemeBloc(initialDark: isDarkMode)),
        BlocProvider<FeedBloc>(create: (context) => FeedBloc(feedService: FeedService())),
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
      appID: 332535805,
      appSign: '69ad138a7a325207f10a27865542726ead7f623ec01cbbd625e9765301e52308',
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
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            navigatorKey: NotificationService.navigatorKey,
            title: 'Phan Gia',
            debugShowCheckedModeBanner: false,
            themeMode: themeState.themeMode,
            // ─── DARK THEME ─────────────────────────────────────────────
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              primaryColor: const Color(0xFFF57C00),
              scaffoldBackgroundColor: const Color(0xFF0F1B2A),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFF57C00),
                brightness: Brightness.dark,
                primary: const Color(0xFFF57C00),
                secondary: const Color(0xFFFFB300),
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
                selectedColor: const Color(0xFFFFB300),
                labelStyle: const TextStyle(color: Colors.white),
                secondaryLabelStyle: const TextStyle(color: Colors.white),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF0F1B2A),
                surfaceTintColor: Colors.transparent,
                centerTitle: true,
                foregroundColor: Colors.white,
                titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF57C00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: const Color(0xFF0F1B2A),
                indicatorColor: const Color(0xFFF57C00).withOpacity(0.2),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const IconThemeData(color: Color(0xFFF57C00));
                  }
                  return const IconThemeData(color: Colors.white54);
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(color: Color(0xFFF57C00), fontWeight: FontWeight.bold);
                  }
                  return const TextStyle(color: Colors.white54);
                }),
              ),
            ),
            // ─── LIGHT THEME ─────────────────────────────────────────────
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              primaryColor: const Color(0xFFF57C00),
              scaffoldBackgroundColor: const Color(0xFFF5F5F5),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFF57C00),
                brightness: Brightness.light,
                primary: const Color(0xFFF57C00),
                secondary: const Color(0xFFFFB300),
                surface: Colors.white,
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 2,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              chipTheme: ChipThemeData(
                backgroundColor: Colors.orange.shade50,
                selectedColor: const Color(0xFFF57C00),
                labelStyle: const TextStyle(color: Colors.black87),
                secondaryLabelStyle: const TextStyle(color: Colors.white),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                centerTitle: true,
                foregroundColor: Colors.black87,
                titleTextStyle: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
                elevation: 0,
                shadowColor: Colors.black12,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF57C00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              navigationBarTheme: NavigationBarThemeData(
                backgroundColor: Colors.white,
                indicatorColor: const Color(0xFFF57C00).withOpacity(0.15),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const IconThemeData(color: Color(0xFFF57C00));
                  }
                  return const IconThemeData(color: Colors.black45);
                }),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(color: Color(0xFFF57C00), fontWeight: FontWeight.bold);
                  }
                  return const TextStyle(color: Colors.black45);
                }),
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
              } else if (settings.name == '/caro_room') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) {
                    final authState = context.read<AuthBloc>().state;
                    final uid = args['currentUserUid'] ?? (authState is AuthAuthenticated ? authState.user.uid : '');
                    
                    return BlocProvider(
                      create: (_) => CaroBloc(CaroService())..add(ListenRoomEvent(args['roomId'])),
                      child: CaroScreen(currentUserUid: uid),
                    );
                  }
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
          );
        },
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
    final game = data['game'] ?? 'tien_len';
    final isCaro = game == 'caro';
    
    final authState = context.read<AuthBloc>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isCaro ? const Color(0xFF2A1F10) : const Color(0xFF1B4D3E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isCaro ? const Color(0xFFD2A679) : Colors.amberAccent, width: 2),
            boxShadow: [
              BoxShadow(
                color: (isCaro ? const Color(0xFFD2A679) : Colors.amberAccent).withOpacity(0.3), 
                blurRadius: 20
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCaro ? Icons.grid_on_rounded : Icons.videogame_asset, 
                color: isCaro ? const Color(0xFFD2A679) : Colors.amberAccent, 
                size: 40
              ),
              const SizedBox(height: 15),
              Text('${data['fromName']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Text(
                isCaro ? 'mời bạn chơi Cờ Caro!' : 'mời bạn chơi Tiến Lên!', 
                style: const TextStyle(color: Colors.white70, fontSize: 14)
              ),
              const SizedBox(height: 10),
              if (!isCaro)
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
                      
                      if (isCaro && currentUser != null) {
                        await CaroService().joinRoom(
                          roomId: data['roomId'],
                          uid: currentUser.uid,
                          name: currentUser.displayName ?? "Guest",
                        );
                        NotificationService.navigatorKey.currentState?.pushNamed(
                          '/caro_room',
                          arguments: {
                            'roomId': data['roomId'],
                            'currentUserUid': currentUser.uid,
                          }
                        );
                      } else {
                        NotificationService.navigatorKey.currentState?.pushNamed(
                          '/tien_len_room',
                          arguments: {'roomId': data['roomId']}
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCaro ? const Color(0xFFD2A679) : Colors.amberAccent, 
                      foregroundColor: Colors.black
                    ),
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
