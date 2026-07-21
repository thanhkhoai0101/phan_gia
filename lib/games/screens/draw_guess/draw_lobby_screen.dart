import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../services/draw_guess/draw_guess_service.dart';
import '../../models/draw_guess/draw_room_model.dart';
import 'draw_room_screen.dart';

class DrawLobbyScreen extends StatefulWidget {
  const DrawLobbyScreen({super.key});

  @override
  State<DrawLobbyScreen> createState() => _DrawLobbyScreenState();
}

class _DrawLobbyScreenState extends State<DrawLobbyScreen> with SingleTickerProviderStateMixin {
  final DrawGuessService _service = DrawGuessService();
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _createRoom() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      setState(() => _isLoading = true);
      try {
        final roomId = await _service.createRoom(
          hostId: authState.user.uid,
          hostName: authState.user.displayName,
          hostAvatar: authState.user.avatarUrl,
        );
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => DrawRoomScreen(roomId: roomId),
          ));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _joinRoom(DrawRoomModel room) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      if (room.players.length >= 8) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phòng đã đầy!')));
        return;
      }
      setState(() => _isLoading = true);
      try {
        bool isInRoom = room.players.any((p) => p.uid == authState.user.uid);
        if (!isInRoom) {
          await _service.joinRoom(room.id, DrawPlayerModel(
            uid: authState.user.uid,
            displayName: authState.user.displayName,
            avatarUrl: authState.user.avatarUrl,
            score: 0,
            hasGuessed: false,
          ));
        }
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => DrawRoomScreen(roomId: room.id),
          ));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6A1B9A), Color(0xFFAD1457), Color(0xFF1565C0)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background decorative circles
              Positioned(top: -60, right: -60, child: _buildDecorCircle(200, Colors.white.withValues(alpha: 0.05))),
              Positioned(bottom: 100, left: -80, child: _buildDecorCircle(250, Colors.white.withValues(alpha: 0.04))),

              Column(
                children: [
                  // AppBar custom
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        ),
                        const Expanded(
                          child: Text('🎨 Vẽ & Đoán', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  // Header Banner
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Text('✏️', style: TextStyle(fontSize: 48)),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Vẽ & Đoán', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('Vẽ thật tài, đoán thật nhanh!\n2-8 người chơi', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Room list title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        const Text('Phòng đang mở', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: StreamBuilder<List<DrawRoomModel>>(
                            stream: _service.listenToRooms(),
                            builder: (ctx, snap) => Text(
                              '${snap.data?.length ?? 0} phòng',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),

                  // Room List
                  Expanded(
                    child: StreamBuilder<List<DrawRoomModel>>(
                      stream: _service.listenToRooms(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Colors.white));
                        }
                        final rooms = snapshot.data ?? [];
                        if (rooms.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🎭', style: TextStyle(fontSize: 64)),
                                const SizedBox(height: 12),
                                const Text('Chưa có phòng nào!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Hãy tạo phòng đầu tiên 🎉', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                              ],
                            ),
                          );
                        }
                        return FadeTransition(
                          opacity: _fadeAnim,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: rooms.length,
                            itemBuilder: (context, index) => _buildRoomCard(rooms[index]),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _createRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF6A1B9A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.add_circle_outline, size: 24),
                        label: const Text('Tạo phòng mới', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),

              if (_isLoading)
                Container(
                  color: Colors.black38,
                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomCard(DrawRoomModel room) {
    final host = room.players.isNotEmpty ? room.players.first : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: Colors.purple.shade200,
          backgroundImage: host?.avatarUrl != null ? CachedNetworkImageProvider(host!.avatarUrl!) : null,
          child: host?.avatarUrl == null ? const Text('🎨', style: TextStyle(fontSize: 20)) : null,
        ),
        title: Text(
          'Phòng của ${host?.displayName ?? "Ai đó"}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.people, color: Colors.white60, size: 14),
            const SizedBox(width: 4),
            Text('${room.players.length}/8 người', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _joinRoom(room),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF6A1B9A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Vào', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildDecorCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
