import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
        backgroundColor: const Color(0xFF151515),
        body: SafeArea(
          child: BlocBuilder<CaroBloc, CaroState>(
            builder: (context, state) {
              if (state.status == CaroStatus.initial ||
                  state.status == CaroStatus.loading ||
                  state.room == null) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD2A679)),
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
    );
  }

  Widget _buildHeader(BuildContext context, String roomId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text(
            "Cờ Caro Online",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Spacer(),
          // Mã phòng - bấm để copy
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: roomId));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Đã copy mã phòng: $roomId"),
                  backgroundColor: const Color(0xFF2A2A2A),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD2A679), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.copy, color: Color(0xFFD2A679), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    roomId,
                    style: const TextStyle(
                      color: Color(0xFFD2A679),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard({
    required String name,
    required bool isBlack,
    required bool isTurn,
    required bool isMe,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF222222),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTurn ? Colors.greenAccent : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isBlack ? Colors.black : Colors.white,
              border: Border.all(color: Colors.grey.shade600, width: 2),
              boxShadow: [
                BoxShadow(
                  color: (isBlack ? Colors.black : Colors.white).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ],
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
                          color: const Color(0xFFD2A679).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFD2A679), width: 1),
                        ),
                        child: const Text(
                          "Bạn",
                          style: TextStyle(color: Color(0xFFD2A679), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isBlack ? "Quân Đen (đi trước)" : "Quân Trắng",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isTurn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent, width: 1),
              ),
              child: const Text(
                "Lượt đi",
                style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBoard(BuildContext context, CaroState state, bool myTurn) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 16)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 3,
          child: AspectRatio(
            aspectRatio: 1,
            child: BoardCanvas(
              board: state.room!.board,
              onTap: (row, col) {
                if (!myTurn) return;
                if (state.status != CaroStatus.playing) return;
                context.read<CaroBloc>().add(PlacePieceEvent(
                  row: row,
                  col: col,
                  uid: widget.currentUserUid,
                ));
              },
            ),
          ),
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
