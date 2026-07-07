import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../chicken_shooter_game.dart';
import '../services/shop_service.dart';
import 'bullet.dart';
import 'dart:math';

class Player extends SpriteComponent with HasGameReference<ChickenShooterGame>, CollisionCallbacks {
  double fireTimer = 0.0;
  double fireInterval = 0.5;

  // Weapon flags — combinable
  bool hasTripleShot = false;
  bool hasRapidFire = false;
  bool hasLaser = false;
  bool hasHoming = false;

  int baseWeapon = 1;
  double tripleShotTimer = 0.0;
  double rapidFireTimer = 0.0;
  double laserTimer = 0.0;
  double homingTimer = 0.0;
  static const double weaponDuration = 15.0; // 15 seconds duration for picked up cores

  int extraDamage = 0;
  bool hasShield = false;

  static const double playerSize = 60.0;

  Player() : super(size: Vector2.all(playerSize), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    position = Vector2(game.size.x / 2, game.size.y - 100);
    sprite = await game.loadSprite('ban_ga/player.png');
    angle = pi / 2;
    add(RectangleHitbox());
    initBaseWeapon(ShopService().startingWeapon);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (hasShield) {
      final shieldPaint = Paint()
        ..color = Colors.lightBlueAccent.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 1.5, shieldPaint);
    }
  }

  void _restoreBaseWeapon() {
    if (baseWeapon == 2 && laserTimer <= 0) hasTripleShot = true;
    if (baseWeapon == 4 && tripleShotTimer <= 0) hasLaser = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    fireTimer += dt;
    if (fireTimer >= fireInterval) {
      fireTimer = 0;
      fireBullets();
    }

    bool changed = false;
    if (tripleShotTimer > 0) {
      tripleShotTimer -= dt;
      if (tripleShotTimer <= 0 && baseWeapon != 2) {
        hasTripleShot = false;
        _restoreBaseWeapon();
        changed = true;
      }
    }
    if (rapidFireTimer > 0) {
      rapidFireTimer -= dt;
      if (rapidFireTimer <= 0 && baseWeapon != 3) {
        hasRapidFire = false;
        changed = true;
      }
    }
    if (laserTimer > 0) {
      laserTimer -= dt;
      if (laserTimer <= 0 && baseWeapon != 4) {
        hasLaser = false;
        _restoreBaseWeapon();
        changed = true;
      }
    }
    if (homingTimer > 0) {
      homingTimer -= dt;
      if (homingTimer <= 0 && baseWeapon != 5) {
        hasHoming = false;
        changed = true;
      }
    }

    if (changed) {
      _updateFireInterval();
      game.notifyWeaponUpdate();
    }
  }

  void fireBullets() {
    int damage = 1 + extraDamage;
    final bulletPos = position.clone()..y -= size.y / 2;

    if (hasLaser) {
      game.add(LaserBeam(position: bulletPos.clone(), damage: damage, isHoming: hasHoming));
      // Triple shot is not combined with laser anymore, but just in case:
      if (hasTripleShot) {
        game.add(LaserBeam(position: bulletPos.clone(), velocityX: -200, damage: damage, isHoming: hasHoming));
        game.add(LaserBeam(position: bulletPos.clone(), velocityX: 200, damage: damage, isHoming: hasHoming));
      }
    } else {
      game.add(Bullet(position: bulletPos.clone(), damage: damage, isHoming: hasHoming));
      if (hasTripleShot) {
        game.add(Bullet(position: bulletPos.clone(), velocityX: -110, damage: damage, isHoming: hasHoming));
        game.add(Bullet(position: bulletPos.clone(), velocityX: 110, damage: damage, isHoming: hasHoming));
      }
    }
  }

  void move(Vector2 delta) {
    position.add(delta);
    position.x = position.x.clamp(size.x / 2, game.size.x - size.x / 2);
    position.y = position.y.clamp(size.y / 2, game.size.y - size.y / 2);
  }

  /// Activate a weapon mode for a limited time
  void activateWeapon(int type) {
    switch (type) {
      case 2: 
        hasTripleShot = true; 
        tripleShotTimer = weaponDuration; 
        hasLaser = false; // Override laser
        laserTimer = 0;
        break;
      case 3: hasRapidFire = true; rapidFireTimer = weaponDuration; break;
      case 4: 
        hasLaser = true; 
        laserTimer = weaponDuration; 
        hasTripleShot = false; // Override triple shot
        tripleShotTimer = 0;
        break;
      case 5: hasHoming = true; homingTimer = weaponDuration; break;
    }
    _updateFireInterval();
    game.notifyWeaponUpdate();
  }

  // Kept for backward-compat calls
  void upgradeWeapon(int type) => activateWeapon(type);

  /// Called at match start / after shop visit
  void initBaseWeapon(int type) {
    baseWeapon = type;
    hasTripleShot = type == 2;
    hasRapidFire = type == 3;
    hasLaser = false;
    hasHoming = false;
    
    tripleShotTimer = 0;
    rapidFireTimer = 0;
    laserTimer = 0;
    homingTimer = 0;
    
    _updateFireInterval();
    game.notifyWeaponUpdate();
  }

  void updateBaseWeapon(int newBase) => initBaseWeapon(newBase);

  void _updateFireInterval() {
    if (hasLaser) {
      fireInterval = 0.1;
    } else if (hasRapidFire) {
      fireInterval = 0.15;
    } else {
      fireInterval = 0.5;
    }
  }

  void activateShield() => hasShield = true;

  void increaseDamage() {
    extraDamage++;
    game.notifyDamageUpdate();
  }
}
