import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/caro_local/caro_local_bloc.dart';
import '../../widgets/board_canvans.dart';

class CaroLocalScreen extends StatelessWidget {
  const CaroLocalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF09141E),
              Color(0xFF0F2634),
              Color(0xFF0C1924),
            ],
          ),
        ),
        child: SafeArea(
          child: BlocBuilder<CaroLocalBloc, CaroLocalState>(
            builder: (context, state) {
              return Column(
                children: [
                  _buildHeader(context),
                  _buildPlayerTop(state),
                  Expanded(child: _buildBoard(context, state)),
                  _buildPlayerBottom(state),
                  _buildBottomBar(context, state),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tàn Cuộc Cờ Năm Quân 🤖",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  letterSpacing: 0.5,
                  shadows: [Shadow(color: Color(0xFF00E5FF), blurRadius: 8)],
                ),
              ),
              Text(
                "Luyện Tập Với Máy AI",
                style: TextStyle(color: Color(0xFF80DEEA), fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _playerCard({
    required String name,
    required bool isBlack,
    required bool isTurn,
    required bool isBot,
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
            ),
            child: Icon(
              isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
              color: isBlack ? const Color(0xFFFFD54F) : const Color(0xFF0097A7),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isTurn ? "Đang suy nghĩ..." : (isBlack ? "Quân Đen (Đi trước)" : "Quân Trắng"),
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

  Widget _buildBoard(BuildContext context, CaroLocalState state) {
    final isMyTurn = state.status == CaroLocalStatus.playing && state.turn == 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 3,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BoardCanvas(
          board: state.board,
          isMyTurn: isMyTurn,
          myPiece: 1, // User is 1 (Black/X)
          onConfirmMove: (row, col) {
            context.read<CaroLocalBloc>().add(UserPlacePieceEvent(row, col));
          },
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, CaroLocalState state) {
    if (state.status == CaroLocalStatus.finished) {
      String winText = state.winner == 1 ? "🎉 BẠN ĐÃ THẮNG! 🎉" : "🤖 BOT ĐÃ THẮNG!";
      Color winColor = state.winner == 1 ? Colors.greenAccent : Colors.redAccent;

      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              winText,
              style: TextStyle(
                color: winColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                context.read<CaroLocalBloc>().add(ResetLocalGameEvent());
              },
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                "Chơi lại",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    return Container(
      height: 70,
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.exit_to_app, color: Colors.white),
              label: const Text("Thoát", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerTop(CaroLocalState state) {
    return _playerCard(
      name: "Bot Thông Minh",
      isBlack: false,
      isTurn: state.turn == 2 && state.status == CaroLocalStatus.playing,
      isBot: true,
    );
  }

  Widget _buildPlayerBottom(CaroLocalState state) {
    return _playerCard(
      name: "Bạn (Người chơi)",
      isBlack: true,
      isTurn: state.turn == 1 && state.status == CaroLocalStatus.playing,
      isBot: false,
    );
  }
}
