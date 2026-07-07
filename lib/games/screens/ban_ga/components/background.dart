import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../chicken_shooter_game.dart';

class SpaceBackground extends PositionComponent with HasGameReference<ChickenShooterGame> {
  final List<Star> stars = [];
  final Random rnd = Random();

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = game.size;

    // Generate initial stars
    for (int i = 0; i < 100; i++) {
      stars.add(Star(
        position: Vector2(rnd.nextDouble() * size.x, rnd.nextDouble() * size.y),
        speed: 20 + rnd.nextDouble() * 80,
        radius: 1 + rnd.nextDouble() * 2,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (var star in stars) {
      star.position.y += star.speed * dt;
      if (star.position.y > size.y) {
        star.position.y = 0;
        star.position.x = rnd.nextDouble() * size.x;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    for (var star in stars) {
      canvas.drawCircle(star.position.toOffset(), star.radius, paint);
    }
  }
}

class Star {
  Vector2 position;
  double speed;
  double radius;

  Star({required this.position, required this.speed, required this.radius});
}
