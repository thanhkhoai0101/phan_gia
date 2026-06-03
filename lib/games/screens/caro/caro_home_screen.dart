import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phan_family/games/services/caro_service.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';

import '../../blocs/caro/caro_bloc.dart';
import '../../blocs/caro_local/caro_local_bloc.dart';
import '../../models/caro_model.dart';
import 'caro_local_screen.dart';
import 'caro_screen.dart';

class CaroHomeScreen extends StatefulWidget {
  const CaroHomeScreen({super.key});

  @override
  State<CaroHomeScreen> createState() => _CaroHomeScreenState();
}

class _CaroHomeScreenState extends State<CaroHomeScreen> {
  CaroModel? _activeRoom;
  bool _loadingActiveRoom = true;

  @override
  void initState() {
    super.initState();
    _checkActiveRoom();
  }

  Future<void> _checkActiveRoom() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      setState(() => _loadingActiveRoom = false);
      return;
    }

    final room = await CaroService().getActiveRoom(uid: authState.user.uid);
    if (mounted) {
      setState(() {
        _activeRoom = room;
        _loadingActiveRoom = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Cờ Caro Phân Gia", 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.grid_on_rounded,
                  size: 100,
                  color: Color(0xFFD2A679),
                ),
                const SizedBox(height: 48),
        
                // Banner ván dở (nếu có)
                if (!_loadingActiveRoom && _activeRoom != null) ...[
                  _buildResumeBanner(context, _activeRoom!),
                  const SizedBox(height: 20),
                ],
        
                _buildMenuButton(
                  context,
                  icon: Icons.smart_toy,
                  label: "🕹 Chơi với Máy",
                  color: Colors.greenAccent,
                  onPressed: () {
                    _showDifficultyDialog(context);
                  },
                ),
                const SizedBox(height: 20),
                _buildMenuButton(
                  context,
                  icon: Icons.add_circle,
                  label: "🎮 Tạo phòng Online",
                  color: Colors.blueAccent,
                  onPressed: () => _createRoom(context),
                ),
                const SizedBox(height: 20),
                _buildMenuButton(
                  context,
                  icon: Icons.login,
                  label: "🚪 Vào phòng Online",
                  color: Colors.orangeAccent,
                  onPressed: () => _joinRoomDialog(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResumeBanner(BuildContext context, CaroModel room) {
    final authState = context.read<AuthBloc>().state;
    final uid = authState is AuthAuthenticated ? authState.user.uid : "";
    final isHost = room.hostId == uid;
    final myName = isHost ? room.hostName : room.guestName;
    final opponentName = isHost ? room.guestName : room.hostName;

    return GestureDetector(
      onTap: () => _resumeRoom(context, room, uid),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2A1F10), Color(0xFF3A2C18)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD2A679), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.restore, color: Color(0xFFD2A679), size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Có ván cờ đang dở!",
                    style: TextStyle(
                      color: Color(0xFFD2A679),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Phòng #${room.roomId} • ${opponentName.isNotEmpty ? opponentName : 'Chờ đối thủ'}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD2A679),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "Vào tiếp",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resumeRoom(BuildContext context, CaroModel room, String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => CaroBloc(CaroService())..add(ListenRoomEvent(room.roomId)),
          child: CaroScreen(currentUserUid: uid),
        ),
      ),
    ).then((_) {
      // Refresh lại khi quay về (ván có thể đã xong)
      _checkActiveRoom();
    });
  }

  Widget _buildMenuButton(BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2A2A2A),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withOpacity(0.5), width: 2),
        ),
        elevation: 5,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _createRoom(BuildContext context) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    
    final user = authState.user;

    String roomId = await CaroService().createRoom(
      hostId: user.uid,
      hostName: user.displayName ?? "Host",
    );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => CaroBloc(CaroService())..add(ListenRoomEvent(roomId)),
            child: CaroScreen(currentUserUid: user.uid),
          ),
        ),
      ).then((_) => _checkActiveRoom());
    }
  }

  Future<void> _joinRoomDialog(BuildContext context) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final user = authState.user;

    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            "Nhập mã phòng",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "VD: 123456",
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            ),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                String roomId = controller.text.trim();
                if (roomId.isEmpty) return;

                await CaroService().joinRoom(
                  roomId: roomId,
                  uid: user.uid,
                  name: user.displayName ?? "Guest",
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BlocProvider(
                        create: (_) => CaroBloc(CaroService())..add(ListenRoomEvent(roomId)),
                        child: CaroScreen(currentUserUid: user.uid),
                      ),
                    ),
                  ).then((_) => _checkActiveRoom());
                }
              },
              child: const Text("Vào", style: TextStyle(color: Colors.orangeAccent)),
            )
          ],
        );
      },
    );
  }

  void _showDifficultyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text(
            "Chọn Cấp Độ Khó",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDifficultyOption(context, "Siêu Dễ", 1, Colors.green),
              _buildDifficultyOption(context, "Dễ", 2, Colors.lightGreen),
              _buildDifficultyOption(context, "Bình Thường", 3, Colors.yellow),
              _buildDifficultyOption(context, "Khó", 4, Colors.orange),
              _buildDifficultyOption(context, "Siêu Khó", 5, Colors.red),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDifficultyOption(BuildContext context, String title, int level, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.2),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: color, width: 2),
          ),
        ),
        onPressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (_) => CaroLocalBloc(difficulty: level),
                child: const CaroLocalScreen(),
              ),
            ),
          );
        },
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
