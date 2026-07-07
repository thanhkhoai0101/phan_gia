import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../chicken_shooter_game.dart';
import 'player.dart';

enum ItemType { tripleShot, rapidFire, shield, laser, nuke, coin, damageCore, homingCore, heartCore }

class DropItem extends PositionComponent with HasGameReference<ChickenShooterGame>, CollisionCallbacks {
  static const double itemSize = 30.0;
  final ItemType type;

  DropItem({required Vector2 position, required this.type}) : super(position: position, size: Vector2.all(itemSize), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    Color color;
    switch (type) {
      case ItemType.tripleShot:
        color = Colors.green;
        break;
      case ItemType.rapidFire:
        color = Colors.cyan;
        break;
      case ItemType.shield:
        color = Colors.blue;
        break;
      case ItemType.laser:
        color = Colors.yellowAccent;
        break;
      case ItemType.nuke:
        color = Colors.redAccent;
        break;
      case ItemType.coin:
        color = Colors.amberAccent;
        break;
      case ItemType.damageCore:
        color = Colors.deepPurpleAccent;
        break;
      case ItemType.homingCore:
        color = Colors.pinkAccent;
        break;
      case ItemType.heartCore:
        color = Colors.redAccent;
        break;
    }
    
    final paint = Paint()..color = color;
    if (type == ItemType.coin) {
      canvas.drawCircle(Offset(size.x/2, size.y/2), size.x/2, paint);
    } else {
      canvas.drawRect(size.toRect(), paint);
    }
    
    // Draw initial
    final textPainter = TextPainter(
      text: TextSpan(
        text: switch (type) {
          ItemType.coin => '\$',
          ItemType.damageCore => 'D',
          ItemType.homingCore => '🎯',
          ItemType.heartCore => '♥',
          _ => type.name[0].toUpperCase(),
        },
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas, 
      Offset((size.x - textPainter.width) / 2, (size.y - textPainter.height) / 2)
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += 150 * dt;

    if (position.y > game.size.y + size.y) {
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Player) {
      switch (type) {
        case ItemType.tripleShot:
          other.upgradeWeapon(2);
          break;
        case ItemType.rapidFire:
          other.upgradeWeapon(3);
          break;
        case ItemType.laser:
          other.upgradeWeapon(4);
          break;
        case ItemType.shield:
          other.activateShield();
          break;
        case ItemType.nuke:
          game.clearAllEnemies();
          break;
        case ItemType.coin:
          game.addCoins(10);
          break;
        case ItemType.damageCore:
          other.increaseDamage();
          break;
        case ItemType.homingCore:
          other.activateWeapon(5);
          break;
        case ItemType.heartCore:
          game.addTempHp();
          break;
      }
      if (type != ItemType.coin && type != ItemType.damageCore && type != ItemType.heartCore) {
        game.addScore(50);
      } else if (type == ItemType.damageCore) {
        game.addScore(100);
      } else if (type == ItemType.homingCore) {
        game.addScore(80);
      }
      removeFromParent();
    }
  }
}
