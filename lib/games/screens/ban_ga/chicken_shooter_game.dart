import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'components/player.dart';
import 'components/drop_item.dart';
import 'components/enemy.dart';
import 'components/boss.dart';
import 'components/background.dart';
import 'components/explosion.dart';
import 'services/shop_service.dart';

class ChickenShooterGame extends FlameGame with PanDetector, HasCollisionDetection {
  late Player player;
  
  int score = 0;
  int hp = 3;
  int level = 1;
  
  double spawnTimer = 0.0;
  double spawnInterval = 2.0;

  bool isGameOver = false;
  bool isBossActive = false;
  final Random random = Random();

  final Function(int) onScoreUpdate;
  final Function(int) onHpUpdate;
  final Function(int) onLevelUpdate;
  final Function() onGameOver;
  final Function(int) onDamageUpdate;
  final Function(bool, bool, bool, bool) onWeaponUpdate;

  ChickenShooterGame({
    required this.onScoreUpdate,
    required this.onHpUpdate,
    required this.onLevelUpdate,
    required this.onGameOver,
    required this.onDamageUpdate,
    required this.onWeaponUpdate,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(SpaceBackground());
    _resetGame();
  }

  void _resetGame() {
    score = 0;
    hp = ShopService().maxHp;
    level = 1;
    isGameOver = false;
    isBossActive = false;
    spawnInterval = 2.0;

    onScoreUpdate(score);
    onHpUpdate(hp);
    onLevelUpdate(level);
    onDamageUpdate(1);
    onWeaponUpdate(false, false, false, false);

    // Remove old entities except background
    final toRemove = children.where((c) => c is! SpaceBackground).toList();
    removeAll(toRemove);

    player = Player();
    add(player);
  }

  void restart() {
    _resetGame();
  }

  @override
  void update(double dt) {
    if (isGameOver) return;
    super.update(dt);

    if (!isBossActive) {
      spawnTimer += dt;
      if (spawnTimer >= spawnInterval) {
        spawnTimer = 0;
        spawnEnemy();
      }
    }

    // Check for level up with increasing score requirement
    int calculatedLevel = 1;
    int requiredScore = 0;
    int step = 100;
    while (score >= requiredScore + step) {
      requiredScore += step;
      calculatedLevel++;
      step += 50; // Each subsequent level takes 50 more score
    }

    if (calculatedLevel > level) {
      bool bossSpawned = false;
      for (int l = level + 1; l <= calculatedLevel; l++) {
        if (l % 5 == 0) bossSpawned = true;
      }
      
      level = calculatedLevel;
      onLevelUpdate(level);
      
      if (bossSpawned) {
        spawnBoss();
      } else {
        // Increase difficulty
        spawnInterval = max(0.4, 2.0 - (level * 0.15));
      }
    }
  }

  void spawnEnemy() {
    // 20% chance to spawn a formation if level > 3
    if (level > 3 && random.nextDouble() < 0.2) {
      spawnFormation();
      return;
    }

    final xPos = random.nextDouble() * (size.x - 70) + 35;
    final pos = Vector2(xPos, -70);
    
    // Determine enemy type based on random and level
    final rand = random.nextDouble();
    double levelMult = min(level.toDouble(), 10.0) / 10.0;
    
    if (level > 2 && rand < 0.2) {
      add(FastChicken(position: pos, levelSpeedMult: levelMult, level: level));
    } else if (level > 3 && rand < 0.35) {
      add(ArmoredChicken(position: pos, levelSpeedMult: levelMult, level: level));
    } else if (level > 4 && rand < 0.45) {
      add(Meteorite(position: pos, levelSpeedMult: levelMult, level: level));
    } else {
      add(NormalChicken(position: pos, levelSpeedMult: levelMult, level: level));
    }
  }

  void spawnFormation() {
    double levelMult = min(level.toDouble(), 10.0) / 10.0;
    bool isV = random.nextBool();
    if (isV) {
      // V-shape
      double centerX = size.x / 2;
      for (int i = -2; i <= 2; i++) {
        add(NormalChicken(
            position: Vector2(centerX + i * 50, -70 - (i.abs() * 40)),
            levelSpeedMult: levelMult,
            level: level));
      }
    } else {
      // Horizontal line
      double spacing = size.x / 6;
      for (int i = 1; i <= 5; i++) {
        add(NormalChicken(
            position: Vector2(i * spacing, -70),
            levelSpeedMult: levelMult,
            level: level));
      }
    }
  }

  void spawnBoss() {
    isBossActive = true;
    // Boss HP scales exponentially: base + linear + quadratic
    int bossHp = 50 + (level * 20) + (level * level * 2);
    add(Boss(position: Vector2(size.x / 2, 100), maxHp: bossHp));
  }

  void onBossDefeated() {
    isBossActive = false;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (isGameOver) return;
    player.move(info.delta.global);
  }

  void addScore(int points) {
    score += points;
    onScoreUpdate(score);
  }

  void addCoins(int amount) {
    ShopService().addCoins(amount);
  }

  void notifyDamageUpdate() {
    onDamageUpdate(1 + player.extraDamage);
  }

  void notifyWeaponUpdate() {
    onWeaponUpdate(
      player.hasTripleShot,
      player.hasRapidFire,
      player.hasLaser,
      player.hasHoming,
    );
  }

  void addTempHp() {
    hp++;
    onHpUpdate(hp);
  }
  void takeDamage() {
    if (player.hasShield) {
      player.hasShield = false;
      add(Explosion(position: player.position.clone(), color: const Color(0xFF00BFFF)));
      return;
    }
    
    hp -= 1;
    onHpUpdate(hp);
    add(Explosion(position: player.position.clone(), color: const Color(0xFFFF0000)));
    
    if (hp <= 0) {
      isGameOver = true;
      player.removeFromParent();
      onGameOver();
    }
  }

  void spawnDropItem(Vector2 position, {bool forceSpawn = false}) {
    // 25% chance to drop an item, or forced (e.g. boss death)
    if (forceSpawn || random.nextDouble() < 0.25) {
      final r = random.nextDouble();
      ItemType type;
      if (r < 0.20) {
        type = ItemType.coin;
      } else if (r < 0.30) {
        type = ItemType.damageCore;
      } else if (r < 0.40) {
        type = ItemType.tripleShot;
      } else if (r < 0.50) {
        type = ItemType.rapidFire;
      } else if (r < 0.60) {
        type = ItemType.shield;
      } else if (r < 0.70) {
        type = ItemType.laser;
      } else if (r < 0.80) {
        type = ItemType.homingCore;
      } else if (r < 0.95) {
        type = ItemType.heartCore;
      } else {
        type = ItemType.nuke;
      }
      
      add(DropItem(position: position, type: type));
    }
  }

  void clearAllEnemies() {
    final targets = children.toList();
    for (var child in targets) {
      if (child is Enemy) {
        child.die(spawnDrop: false, explode: true);
      } else if (child is BossEgg) {
        child.removeFromParent();
      }
    }
  }
}
