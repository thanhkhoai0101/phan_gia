import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/notification_service.dart';
import '../../blocs/caro/caro_bloc.dart';
import '../../services/caro_service.dart';
import '../../widgets/board_canvans.dart';

class CaroScreen extends StatefulWidget {
  final String currentUserUid;

  const CaroScreen({super.key, required this.currentUserUid});

  @override
  State<CaroScreen> createState() => _CaroScreenState();
}

class _CaroScreenState extends State<CaroScreen> {
  bool _resultShown = false;

  @override
  void initState() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.initState();
  }
  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CaroBloc, CaroState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == CaroStatus.finished && !_resultShown) {
          _resultShown = true;
          _showResultDialog(context, state);
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF09141E), // Celestial Deep Dark Blue
                Color(0xFF0F2634), // Xianxia Ocean Slate
                Color(0xFF0C1924), // Dark Mystery Cyan
              ],
            ),
          ),
          child: SafeArea(
            child: BlocBuilder<CaroBloc, CaroState>(
              builder: (context, state) {
                if (state.status == CaroStatus.initial ||
                    state.status == CaroStatus.loading ||
                    state.room == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                  );
                }

                final room = state.room!;
                final isHost = room.hostId == widget.currentUserUid;
                final myTurn = (isHost && room.turn == 1) || (!isHost && room.turn == 2);
                final isWaiting = room.status == "waiting";

                return Column(
                  children: [
                    _buildHeader(context, room.roomId),
                    _buildPlayerCard(
                      name: room.hostName.isNotEmpty ? room.hostName : "Host",
                      isBlack: true,
                      isTurn: room.turn == 1,
                      isMe: isHost,
                    ),
                    if (isWaiting)
                      _buildWaitingBanner()
                    else
                      Expanded(child: _buildBoard(context, state, myTurn)),
                    _buildPlayerCard(
                      name: room.guestName.isNotEmpty ? room.guestName : "Đang chờ...",
                      isBlack: false,
                      isTurn: room.turn == 2,
                      isMe: !isHost,
                    ),
                    if (!isWaiting) _buildBottomBar(context, state),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String roomId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF4EE2EC).withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF80DEEA), size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Cờ Năm Quân ⚔️",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  letterSpacing: 0.5,
                  shadows: [Shadow(color: Color(0xFF00E5FF), blurRadius: 8)],
                ),
              ),
              Text(
                "Cờ Caro Thần Thoại",
                style: TextStyle(color: Color(0xFF80DEEA), fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          // Mã phòng - bấm để copy
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: roomId));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Đã copy mã phòng: $roomId"),
                  backgroundColor: const Color(0xFF0F2634),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF193447).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF4EE2EC), width: 1.2),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.2), blurRadius: 8)
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.copy_rounded, color: Color(0xFF4EE2EC), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    roomId,
                    style: const TextStyle(
                      color: Color(0xFFE0F7FA),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingBanner() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFD2A679)),
            const SizedBox(height: 24),
            const Text(
              "Đang chờ đối thủ...",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Gửi mã phòng cho bạn bè nhé!",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD2A679),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                final state = context.read<CaroBloc>().state;
                if (state.room != null) {
                  _showInviteDialog(context, state.room!.roomId, state.room!.hostName);
                }
              },
              icon: const Icon(Icons.person_add),
              label: const Text("Mời bạn bè", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context, String roomId, String hostName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Mời bạn chơi Cờ Caro",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data!.docs
                      .where((doc) => doc.id != widget.currentUserUid)
                      .toList();

                  if (users.isEmpty) {
                    return const Center(
                      child: Text("Không có người dùng nào khác", style: TextStyle(color: Colors.grey)),
                    );
                  }

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final userData = users[index].data() as Map<String, dynamic>;
                      final toUid = users[index].id;
                      final toName = userData['displayName'] ?? 'Người chơi';
                      final fcmToken = userData['fcmToken'];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFD2A679),
                          child: Text(toName[0].toUpperCase(), style: const TextStyle(color: Colors.black)),
                        ),
                        title: Text(toName, style: const TextStyle(color: Colors.white)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent.withOpacity(0.2),
                            foregroundColor: Colors.greenAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _sendInvite(toUid, toName, fcmToken, roomId, hostName),
                          child: const Text("Mời"),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendInvite(String toUid, String toName, String? fcmToken, String roomId, String hostName) async {
    // 1. Tạo bản ghi invite trong Firestore
    final inviteRef = await FirebaseFirestore.instance.collection('invites').add({
      'fromUid': widget.currentUserUid,
      'fromName': hostName,
      'toUid': toUid,
      'toName': toName,
      'roomId': roomId,
      'game': 'caro', // Đánh dấu là Caro
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Gửi Push Notification (nếu người dùng có fcmToken)
    if (fcmToken != null && fcmToken.isNotEmpty) {
      await NotificationService.sendPushNotification(
        fcmToken,
        "Lời mời chơi Cờ Caro 🎮",
        "$hostName vừa mời bạn tham gia ván Cờ Caro. Vào chơi ngay!",
        type: 'game_invite',
        game: 'caro',
        inviteId: inviteRef.id,
        roomId: roomId,
        otherUserId: widget.currentUserUid,
        otherUserName: hostName,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã gửi lời mời đến $toName")),
      );
    }
  }

  Widget _buildPlayerCard({
    required String name,
    required bool isBlack,
    required bool isTurn,
    required bool isMe,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2634).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTurn ? const Color(0xFF00E5FF) : const Color(0xFF4EE2EC).withValues(alpha: 0.2),
          width: isTurn ? 2 : 1,
        ),
        boxShadow: isTurn
            ? [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          // 3D Stone Icon Avatar Badge
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.35, -0.35),
                colors: isBlack
                    ? [const Color(0xFF616161), const Color(0xFF151515)]
                    : [Colors.white, const Color(0xFF80DEEA)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: (isBlack ? Colors.black : const Color(0xFF00E5FF)).withValues(alpha: 0.4),
                  blurRadius: 8,
                )
              ],
            ),
            child: Center(
              child: Text(
                isBlack ? 'X' : 'O',
                style: TextStyle(
                  color: isBlack ? const Color(0xFFFFD54F) : const Color(0xFF0097A7),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00E5FF), width: 1),
                        ),
                        child: const Text(
                          "Bạn",
                          style: TextStyle(color: Color(0xFF80DEEA), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isTurn ? "Đang đặt cờ..." : (isBlack ? "Quân Đen (Đi trước)" : "Quân Trắng"),
                  style: TextStyle(
                    color: isTurn ? const Color(0xFF80DEEA) : Colors.white60,
                    fontSize: 12,
                    fontStyle: isTurn ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
          if (isTurn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.3), blurRadius: 6)
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.edit_location_alt_rounded, color: Color(0xFF00E5FF), size: 14),
                  SizedBox(width: 4),
                  Text(
                    "Lượt đi",
                    style: TextStyle(color: Color(0xFFE0F7FA), fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBoard(BuildContext context, CaroState state, bool myTurn) {
    final room = state.room!;
    final isHost = room.hostId == widget.currentUserUid;
    final myPiece = isHost ? 1 : 2;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BoardCanvas(
          board: room.board,
          isMyTurn: myTurn && state.status == CaroStatus.playing,
          myPiece: myPiece,
          onConfirmMove: (row, col) {
            context.read<CaroBloc>().add(PlacePieceEvent(
              row: row,
              col: col,
              uid: widget.currentUserUid,
            ));
          },
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, CaroState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A2A2A),
                foregroundColor: Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.grey, width: 1),
                ),
              ),
              // Khi thoát giữa chừng, KHÔNG xóa activeRoom để có thể chơi tiếp sau
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.exit_to_app),
              label: const Text("Thoát tạm", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showResultDialog(BuildContext context, CaroState state) {
    final room = state.room!;
    final iWon = (room.winner == 1 && room.hostId == widget.currentUserUid) ||
        (room.winner == 2 && room.guestId == widget.currentUserUid);

    final winnerName = room.winner == 1 ? room.hostName : room.guestName;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                iWon ? "🏆" : "😢",
                style: const TextStyle(fontSize: 60),
              ),
              const SizedBox(height: 12),
              Text(
                iWon ? "Bạn thắng rồi!" : "Thua mất!",
                style: TextStyle(
                  color: iWon ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "$winnerName chiến thắng ván này",
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: const BorderSide(color: Colors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        // Thoát hẳn sau khi ván kết thúc => xóa activeRoom
                        await CaroService().clearActiveRoom(uid: widget.currentUserUid);
                        if (context.mounted) {
                          Navigator.pop(context); // đóng dialog
                          Navigator.pop(context); // thoát màn hình
                        }
                      },
                      child: const Text("Thoát"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD2A679),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context); // đóng dialog
                        _resultShown = false; // cho phép show lại khi ván sau kết thúc
                        context.read<CaroBloc>().add(ResetCaroEvent());
                      },
                      child: const Text("Chơi lại", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
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
