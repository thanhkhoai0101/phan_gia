import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'chicken_shooter_game.dart';
import 'services/shop_service.dart';
import 'shop_screen.dart';
import 'leaderboard_screen.dart';

class BanGaScreen extends StatefulWidget {
  const BanGaScreen({super.key});

  @override
  State<BanGaScreen> createState() => _BanGaScreenState();
}

class _BanGaScreenState extends State<BanGaScreen> {
  ChickenShooterGame? game;
  int score = 0;
  int hp = 3;
  int level = 1;
  int damage = 1;
  bool isGameOver = false;
  
  // Weapon states
  bool hasTripleShot = false;
  bool hasRapidFire = false;
  bool hasLaser = false;
  bool hasHoming = false;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
    await ShopService().loadData();
    hp = ShopService().maxHp;
    game = _buildGame();
    if (mounted) setState(() {});
  }


  ChickenShooterGame _buildGame() {
    return ChickenShooterGame(
      onScoreUpdate: (newScore) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => score = newScore);
          });
        }
      },
      onHpUpdate: (newHp) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => hp = newHp);
          });
        }
      },
      onLevelUpdate: (newLevel) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => level = newLevel);
          });
        }
      },
      onGameOver: () {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (score > ShopService().highScore) {
              await ShopService().saveHighScore(score);
            }
            if (mounted) setState(() => isGameOver = true);
          });
        }
      },
      onDamageUpdate: (newDamage) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => damage = newDamage);
          });
        }
      },
      onWeaponUpdate: (triple, rapid, laser, homing) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                hasTripleShot = triple;
                hasRapidFire = rapid;
                hasLaser = laser;
                hasHoming = homing;
              });
            }
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Bắn Gà'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () async {
              game?.pauseEngine();
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
              game?.resumeEngine();
            },
          ),
          IconButton(
            icon: const Icon(Icons.store),
            onPressed: () async {
              game?.pauseEngine();
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
              setState(() {
                hp = ShopService().maxHp;
              });
              game?.player.updateBaseWeapon(ShopService().startingWeapon);
              game?.resumeEngine();
            },
          )
        ],
      ),
      body: game == null
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
          : Stack(
        children: [
          GameWidget(game: game!),
          // HUD (Heads Up Display)
          Positioned(
            top: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⭐ $score', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
                Text('🏆 Kỷ lục: ${ShopService().highScore}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                Text('🚀 Level $level', style: const TextStyle(color: Colors.yellowAccent, fontSize: 18)),
                Row(
                  children: List.generate(ShopService().maxHp, (index) => Icon(
                    Icons.favorite,
                    color: index < hp ? Colors.redAccent : Colors.grey.withValues(alpha: 0.4),
                    size: 22,
                  )),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amberAccent, size: 18),
                    const SizedBox(width: 4),
                    Text('${ShopService().coins}', style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                // Damage indicator
                Row(
                  children: [
                    const Text('⚔️', style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 4),
                    Text(
                      'Dame: $damage',
                      style: TextStyle(
                        color: damage > 1 ? Colors.purpleAccent : Colors.white70,
                        fontSize: 14,
                        fontWeight: damage > 1 ? FontWeight.bold : FontWeight.normal,
                        shadows: damage > 1
                            ? [const Shadow(blurRadius: 6, color: Colors.purple)]
                            : [],
                      ),
                    ),
                    if (damage > 1) ...
                      List.generate(damage - 1, (_) =>
                        const Icon(Icons.flash_on, color: Colors.purpleAccent, size: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                // Weapon indicators
                Row(
                  children: [
                    if (hasTripleShot) const Text('🔱', style: TextStyle(fontSize: 16)),
                    if (hasTripleShot) const SizedBox(width: 4),
                    if (hasRapidFire) const Text('🔥', style: TextStyle(fontSize: 16)),
                    if (hasRapidFire) const SizedBox(width: 4),
                    if (hasLaser) const Text('⚡', style: TextStyle(fontSize: 16)),
                    if (hasLaser) const SizedBox(width: 4),
                    if (hasHoming) const Text('🎯', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),
          if (isGameOver)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'GAME OVER',
                      style: TextStyle(color: Colors.red, fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Score: $score',
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        setState(() {
                          isGameOver = false;
                          hp = ShopService().maxHp;
                          damage = 1;
                          hasTripleShot = false;
                          hasRapidFire = false;
                          hasLaser = false;
                          hasHoming = false;
                        });
                        game!.restart();
                      },
                      child: const Text('Chơi lại', style: TextStyle(color: Colors.white, fontSize: 20)),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
