import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../chicken_shooter_game.dart';
import 'player.dart';
import 'explosion.dart';

abstract class Enemy extends SpriteComponent with HasGameReference<ChickenShooterGame>, CollisionCallbacks {
  double speedY;
  int hp;
  final Color color;
  final int scoreValue;
  final bool isIndestructible;
  final String spriteName;

  Enemy({
    required Vector2 position,
    required Vector2 size,
    required this.speedY,
    required this.hp,
    required this.color,
    required this.spriteName,
    this.scoreValue = 10,
    this.isIndestructible = false,
  }) : super(position: position, size: size, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    sprite = await game.loadSprite('ban_ga/$spriteName.png');
    add(RectangleHitbox());
  }


  @override
  void update(double dt) {
    super.update(dt);
    position.y += speedY * dt;

    if (position.y > game.size.y + size.y) {
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Player) {
      game.takeDamage();
      die(spawnDrop: false, explode: true);
    }
  }

  void takeHit([int damage = 1]) {
    if (isIndestructible) return;
    hp -= damage;
    if (hp <= 0) {
      die(spawnDrop: true, explode: true);
    }
  }

  void die({bool spawnDrop = true, bool explode = true}) {
    if (isRemoved) return;
    
    if (spawnDrop) {
      game.addScore(scoreValue);
      game.spawnDropItem(position.clone());
    }

    if (explode) {
      game.add(Explosion(position: position.clone(), color: color));
    }

    removeFromParent();
  }
}

class NormalChicken extends Enemy {
  NormalChicken({required super.position, required double levelSpeedMult, required int level})
      : super(
          size: Vector2.all(50.0),
          speedY: 100.0 + (levelSpeedMult * 20.0),
          hp: 1 + (level ~/ 5),
          color: Colors.orange,
          spriteName: 'chicken',
        );
}

class FastChicken extends Enemy {
  FastChicken({required super.position, required double levelSpeedMult, required int level})
      : super(
          size: Vector2.all(35.0),
          speedY: 250.0 + (levelSpeedMult * 30.0),
          hp: 1 + (level ~/ 5),
          color: Colors.redAccent,
          scoreValue: 20,
          spriteName: 'chicken',
        );
}

class ArmoredChicken extends Enemy {
  ArmoredChicken({required super.position, required double levelSpeedMult, required int level})
      : super(
          size: Vector2.all(60.0),
          speedY: 70.0 + (levelSpeedMult * 10.0),
          hp: 3 + (level ~/ 3),
          color: Colors.grey,
          scoreValue: 30,
          spriteName: 'chicken',
        );
}

class Meteorite extends Enemy {
  Meteorite({required super.position, required double levelSpeedMult, required int level})
      : super(
          size: Vector2.all(70.0),
          speedY: 150.0 + (levelSpeedMult * 15.0),
          hp: 999,
          color: Colors.brown,
          scoreValue: 0,
          isIndestructible: true,
          spriteName: 'meteor',
        );
}
