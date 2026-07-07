import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phan_family/games/blocs/caro/caro_bloc.dart';
import 'package:phan_family/games/screens/tien_len/tien_len_lobby_screen.dart';
import 'package:phan_family/games/services/caro_service.dart';

import 'bau_cua/bau_cua_lobby_screen.dart';
import 'caro/caro_home_screen.dart';
import 'ban_ga/ban_ga_screen.dart';

class GameHubScreen extends StatelessWidget {
  const GameHubScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giải trí Gia đình')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tất cả trò chơi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildGameCard(
                  context,
                  title: 'Tiến Lên',
                  icon: Icons.casino,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TienLenLobbyScreen(),
                      ),
                    );
                  },
                ),
                _buildGameCard(
                  context,
                  title: 'Bầu Cua',
                  icon: Icons.catching_pokemon, // Placeholder
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BauCuaLobbyScreen(),
                      ),
                    );
                  },
                ),
                _buildGameCard(
                  context,
                  title: 'Cờ Caro',
                  icon: Icons.grid_on_rounded,
                  color: Colors.lightBlue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CaroHomeScreen()
                      ),
                    );
                  },
                ),
                _buildGameCard(
                  context,
                  title: 'Bắn Gà',
                  icon: Icons.flight,
                  color: Colors.deepPurple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BanGaScreen()
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: color),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
