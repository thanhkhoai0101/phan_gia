import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_svg/svg.dart';
import 'package:flutter/material.dart';

import '../chicken_shooter_game.dart';
import 'player.dart';
import 'explosion.dart';

class Boss extends SpriteComponent with HasGameReference<ChickenShooterGame>, CollisionCallbacks {
  int maxHp;
  int currentHp;
  double speedX = 150.0;
  int direction = 1;
  double shootTimer = 0.0;
  bool isEnraged = false;

  Boss({required Vector2 position, required this.maxHp})
      : currentHp = maxHp,
        super(position: position, size: Vector2(150, 150), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    sprite = await game.loadSprite('ban_ga/boss.png');

    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    if (isEnraged) {
      // Draw red aura behind boss when enraged
      canvas.drawCircle(Offset(size.x/2, size.y/2), size.x/1.5, Paint()..color = Colors.red.withValues(alpha: 0.3));
    }
    super.render(canvas);

    // Draw health bar
    final hpBarWidth = size.x;
    final hpBarHeight = 10.0;
    final hpRatio = currentHp / maxHp;
    
    final hpBgPaint = Paint()..color = Colors.red;
    canvas.drawRect(Rect.fromLTWH(0, -20, hpBarWidth, hpBarHeight), hpBgPaint);
    
    final hpFgPaint = Paint()..color = Colors.green;
    canvas.drawRect(Rect.fromLTWH(0, -20, hpBarWidth * hpRatio, hpBarHeight), hpFgPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Move side to side
    position.x += speedX * direction * dt;
    if (position.x > game.size.x - size.x / 2) {
      direction = -1;
      position.x = game.size.x - size.x / 2;
    } else if (position.x < size.x / 2) {
      direction = 1;
      position.x = size.x / 2;
    }

    // Shoot eggs
    shootTimer += dt;
    double interval = isEnraged ? 0.6 : 1.5;
    if (shootTimer > interval) {
      shootTimer = 0;
      shootEgg();
      if (isEnraged) {
        // Shoot spread
        game.add(BossEgg(position: position.clone()..y += size.y / 2, velocityX: -100));
        game.add(BossEgg(position: position.clone()..y += size.y / 2, velocityX: 100));
      }
    }
  }

  void shootEgg() {
    game.add(BossEgg(position: position.clone()..y += size.y / 2));
  }

  void takeHit([int damage = 1]) {
    currentHp -= damage;
    if (!isEnraged && currentHp <= maxHp / 2) {
      isEnraged = true;
      speedX = 250.0; // move faster
    }
    
    if (currentHp <= 0) {
      die();
    }
  }

  void die() {
    game.addScore(150);
    // Drop 3 random items
    for (int i = 0; i < 3; i++) {
      game.spawnDropItem(position.clone()..x += (i - 1) * 40, forceSpawn: true);
    }
    
    // Multiple explosions
    game.add(Explosion(position: position.clone(), color: Colors.purple));
    game.add(Explosion(position: position.clone()..x -= 30, color: Colors.red));
    game.add(Explosion(position: position.clone()..x += 30, color: Colors.orange));
    
    game.onBossDefeated();
    removeFromParent();
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Player) {
      game.takeDamage();
    }
  }
}

class BossEgg extends PositionComponent with HasGameReference<ChickenShooterGame>, CollisionCallbacks {
  double velocityX;
  
  BossEgg({required Vector2 position, this.velocityX = 0})
      : super(position: position, size: Vector2(20, 25), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.white;
    canvas.drawOval(size.toRect(), paint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += 200 * dt;
    position.x += velocityX * dt;

    if (position.y > game.size.y + size.y || position.x < -size.x || position.x > game.size.x + size.x) {
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Player) {
      game.takeDamage();
      removeFromParent();
    }
  }
}
