import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/caro_local/caro_local_bloc.dart';
import '../../widgets/board_canvans.dart';

class CaroLocalScreen extends StatelessWidget {
  const CaroLocalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      body: SafeArea(
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            "Chơi với Máy",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTurn ? Colors.greenAccent : Colors.transparent,
          width: 2,
        ),
        boxShadow: isTurn
            ? [
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isBlack ? Colors.black : Colors.white,
              border: Border.all(color: Colors.grey, width: 2),
            ),
            child: Icon(
              isBot ? Icons.smart_toy : Icons.person,
              color: isBlack ? Colors.white : Colors.black,
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (isTurn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent),
              ),
              child: const Text(
                "Lượt đi",
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBoard(BuildContext context, CaroLocalState state) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 5,
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 3,
          child: AspectRatio(
            aspectRatio: 1,
            child: BoardCanvas(
              board: state.board,
              onTap: (row, col) {
                if (state.status == CaroLocalStatus.playing && state.turn == 1) {
                  context.read<CaroLocalBloc>().add(UserPlacePieceEvent(row, col));
                }
              },
            ),
          ),
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
