import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_state.dart';
import '../../blocs/draw_guess/draw_room_bloc.dart';
import '../../blocs/draw_guess/draw_canvas_cubit.dart';
import '../../blocs/draw_guess/draw_room_state_event.dart';
import '../../services/draw_guess/draw_guess_service.dart';
import '../../models/draw_guess/draw_room_model.dart';
import 'components/draw_canvas_widget.dart';
import 'components/draw_chat_widget.dart';

class DrawRoomScreen extends StatelessWidget {
  final String roomId;

  const DrawRoomScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return const Scaffold();

    final currentUid = authState.user.uid;
    final service = DrawGuessService();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => DrawRoomBloc(service, currentUid, authState.user.displayName)
            ..add(JoinDrawRoomEvent(roomId)),
        ),
        BlocProvider(
          create: (_) => DrawCanvasCubit(service, roomId, currentUid),
        ),
      ],
      child: _DrawRoomView(roomId: roomId, currentUid: currentUid),
    );
  }
}

class _DrawRoomView extends StatefulWidget {
  final String roomId;
  final String currentUid;

  const _DrawRoomView({required this.roomId, required this.currentUid});

  @override
  State<_DrawRoomView> createState() => _DrawRoomViewState();
}

class _DrawRoomViewState extends State<_DrawRoomView> {
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    // Timer to update countdown UI every second
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  void _leaveRoom(BuildContext context) async {
    await DrawGuessService().leaveRoom(widget.roomId, widget.currentUid);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _leaveRoom(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A0533),
        body: BlocBuilder<DrawRoomBloc, DrawRoomState>(
          builder: (context, state) {
            final room = state.room;
            if (room == null) {
              return const Center(child: CircularProgressIndicator(color: Colors.purple));
            }

            final isDrawer = room.currentDrawerId == widget.currentUid;
            final isHost = room.hostId == widget.currentUid;

            return SafeArea(
              child: Column(
                children: [
                  // Top bar
                  _buildTopBar(context, room, isDrawer, isHost),

                  // Countdown + Word hint bar
                  if (room.status == 'drawing')
                    _buildGameInfoBar(room, isDrawer),

                  // Player avatars row
                  _buildPlayersRow(room),

                  // Main canvas + chat
                  Expanded(
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            Expanded(
                              child: DrawCanvasWidget(isDrawer: isDrawer && room.status == 'drawing'),
                            ),
                            DrawChatWidget(isDrawer: isDrawer && room.status == 'drawing'),
                          ],
                        ),

                        // Overlays
                        if (room.status == 'waiting')
                          _buildWaitingOverlay(context, room, isHost),
                        if (room.status == 'choosing_word')
                          _buildChoosingWordOverlay(context, room, isDrawer),
                        if (room.status == 'round_end')
                          _buildRoundEndOverlay(room),
                        if (room.status == 'game_over')
                          _buildGameOverOverlay(context, room),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, DrawRoomModel room, bool isDrawer, bool isHost) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _leaveRoom(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🎨 Vẽ & Đoán', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Vòng ${room.currentRound}/${room.totalRounds}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          if (isHost && room.status == 'waiting')
            ElevatedButton(
              onPressed: room.players.length > 1
                  ? () => context.read<DrawRoomBloc>().add(StartGameEvent())
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('BẮT ĐẦU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildGameInfoBar(DrawRoomModel room, bool isDrawer) {
    int timeLeft = 0;
    if (room.roundEndTime != null) {
      timeLeft = room.roundEndTime!.difference(DateTime.now()).inSeconds;
      if (timeLeft < 0) timeLeft = 0;
    }

    String wordDisplay = isDrawer
        ? room.secretWord
        : room.secretWord.replaceAll(RegExp(r'[^\s]'), '_ ').trim();

    Color timerColor = timeLeft > 20 ? Colors.greenAccent : (timeLeft > 10 ? Colors.amber : Colors.redAccent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF2D0D4E),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Timer
          Row(
            children: [
              Icon(Icons.timer, color: timerColor, size: 20),
              const SizedBox(width: 4),
              Text(
                '$timeLeft',
                style: TextStyle(color: timerColor, fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),

          // Word hint
          Expanded(
            child: Center(
              child: Text(
                wordDisplay,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isDrawer ? '✏️ Vẽ' : '🔍 Đoán',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersRow(DrawRoomModel room) {
    return Container(
      height: 88,
      color: const Color(0xFF200A38),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: room.players.length,
        itemBuilder: (context, index) {
          final p = room.players[index];
          final isCurrentDrawer = p.uid == room.currentDrawerId;
          return Container(
            width: 64,
            margin: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrentDrawer ? Colors.amber : (p.hasGuessed ? Colors.greenAccent : Colors.transparent),
                          width: 2.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.purple.shade300,
                        backgroundImage: p.avatarUrl != null ? CachedNetworkImageProvider(p.avatarUrl!) : null,
                        child: p.avatarUrl == null ? Text(p.displayName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
                      ),
                    ),
                    if (isCurrentDrawer)
                      const Positioned(
                        right: -4, top: -4,
                        child: Text('✏️', style: TextStyle(fontSize: 14)),
                      ),
                    if (p.hasGuessed)
                      const Positioned(
                        right: -4, bottom: -4,
                        child: Text('✅', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${p.score}',
                  style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaitingOverlay(BuildContext context, DrawRoomModel room, bool isHost) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF2D0D4E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.purple.shade300, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏳', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text('Đang chờ người chơi...', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('${room.players.length} người đã tham gia', style: const TextStyle(color: Colors.white60, fontSize: 14)),
              const SizedBox(height: 20),
              if (isHost) ...[
                if (room.players.length < 2)
                  const Text('Cần ít nhất 2 người chơi để bắt đầu', style: TextStyle(color: Colors.amber, fontSize: 13))
                else
                  ElevatedButton.icon(
                    onPressed: () => context.read<DrawRoomBloc>().add(StartGameEvent()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('BẮT ĐẦU GAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
              ] else ...[
                const Text('Chờ chủ phòng bắt đầu...', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoosingWordOverlay(BuildContext context, DrawRoomModel room, bool isDrawer) {
    if (isDrawer) {
      return Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF2D0D4E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.purple.shade300, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎯', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text('Chọn từ để vẽ!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Bạn là người vẽ vòng này', style: TextStyle(color: Colors.white60)),
                const SizedBox(height: 24),
                if (room.wordChoices.isEmpty)
                  const CircularProgressIndicator(color: Colors.purple)
                else
                  ...room.wordChoices.map<Widget>((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.read<DrawRoomBloc>().add(WordSelectedEvent(w)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(w, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )),
              ],
            ),
          ),
        ),
      );
    } else {
      final drawer = room.players.where((p) => p.uid == room.currentDrawerId).firstOrNull;
      return Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✏️', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(
                '${drawer?.displayName ?? "Ai đó"} đang chọn từ...',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildRoundEndOverlay(DrawRoomModel room) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF2D0D4E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏰', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              const Text('Hết giờ!', style: TextStyle(color: Colors.redAccent, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Đáp án là:', style: TextStyle(color: Colors.white60, fontSize: 14)),
              const SizedBox(height: 6),
              Text(
                room.secretWord,
                style: const TextStyle(color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Chuẩn bị vòng tiếp theo...', style: TextStyle(color: Colors.white60, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay(BuildContext context, DrawRoomModel room) {
    final sortedPlayers = List.from(room.players)..sort((a, b) => (b as DrawPlayerModel).score.compareTo((a as DrawPlayerModel).score));
    final emojis = ['🥇', '🥈', '🥉'];

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF2D0D4E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              const Text('KẾT THÚC GAME!', style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ...sortedPlayers.take(3).toList().asMap().entries.map<Widget>((entry) {
                final idx = entry.key;
                final p = entry.value as DrawPlayerModel;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(idx < 3 ? emojis[idx] : '🎖️', style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(p.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      Text('${p.score} đ', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _leaveRoom(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Thoát phòng', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
