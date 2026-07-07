import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../chicken_shooter_game.dart';
import 'enemy.dart';
import 'boss.dart';

class Bullet extends PositionComponent with HasGameReference<ChickenShooterGame>, CollisionCallbacks {
  static const double bulletWidth = 8.0;
  static const double bulletHeight = 20.0;
  double speedY = -400.0;
  Vector2 velocity;
  int damage;
  bool isHoming;

  Bullet({required Vector2 position, double velocityX = 0, this.damage = 1, this.isHoming = false})
      : velocity = Vector2(velocityX, -400.0),
        super(position: position, size: Vector2(bulletWidth, bulletHeight), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.yellow;
    canvas.drawRect(size.toRect(), paint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (isHoming) {
      PositionComponent? nearest;
      double nearestDist = double.infinity;
      for (final child in game.children) {
        if (child is Enemy && !child.isIndestructible) {
          final d = position.distanceTo(child.position);
          if (d < nearestDist) { nearestDist = d; nearest = child; }
        } else if (child is Boss) {
          final d = position.distanceTo(child.position);
          if (d < nearestDist) { nearestDist = d; nearest = child; }
        }
      }

      if (nearest != null) {
        final desired = (nearest.position - position).normalized() * 400.0;
        velocity += (desired - velocity) * (dt * 4.0);
        if (velocity.length > 400.0) velocity = velocity.normalized() * 400.0;
      }
    }

    position += velocity * dt;

    if (position.y < -size.y || position.y > game.size.y + size.y ||
        position.x < -size.x || position.x > game.size.x + size.x) {
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Enemy) {
      if (!other.isIndestructible) {
        other.takeHit(damage);
        removeFromParent();
      }
    } else if (other is Boss) {
      other.takeHit(damage);
      removeFromParent();
    }
  }
}

class LaserBeam extends PositionComponent with HasGameReference<ChickenShooterGame>, CollisionCallbacks {
  static const double laserWidth = 15.0;
  static const double laserHeight = 50.0;
  int damage;
  bool isHoming;
  Vector2 velocity;

  LaserBeam({required Vector2 position, double velocityX = 0, this.damage = 1, this.isHoming = false})
      : velocity = Vector2(velocityX, -800.0),
        super(position: position, size: Vector2(laserWidth, laserHeight), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.yellowAccent;
    canvas.drawRect(size.toRect(), paint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (isHoming) {
      PositionComponent? nearest;
      double nearestDist = double.infinity;
      for (final child in game.children) {
        if (child is Enemy && !child.isIndestructible) {
          final d = position.distanceTo(child.position);
          if (d < nearestDist) { nearestDist = d; nearest = child; }
        } else if (child is Boss) {
          final d = position.distanceTo(child.position);
          if (d < nearestDist) { nearestDist = d; nearest = child; }
        }
      }

      if (nearest != null) {
        final desired = (nearest.position - position).normalized() * 800.0;
        velocity += (desired - velocity) * (dt * 5.0);
        if (velocity.length > 800.0) velocity = velocity.normalized() * 800.0;
      }
    }

    position += velocity * dt;

    if (position.y < -size.y || position.y > game.size.y + size.y ||
        position.x < -size.x || position.x > game.size.x + size.x) {
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Enemy) {
      if (!other.isIndestructible) {
        other.takeHit(damage);
        // Laser pierces, doesn't remove itself!
      }
    } else if (other is Boss) {
      other.takeHit(damage);
    }
  }
}
