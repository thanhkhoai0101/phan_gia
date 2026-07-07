import 'dart:math';
import 'package:flame/particles.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class Explosion extends PositionComponent {
  final Color color;

  Explosion({required Vector2 position, required this.color})
      : super(position: position, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final rnd = Random();
    
    // Create a particle explosion
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 20,
          lifespan: 0.5,
          generator: (i) {
            return AcceleratedParticle(
              acceleration: Vector2(
                (rnd.nextDouble() - 0.5) * 500,
                (rnd.nextDouble() - 0.5) * 500,
              ),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  final paint = Paint()
                    ..color = color.withValues(alpha: 1 - particle.progress);
                  canvas.drawCircle(Offset.zero, 3 + rnd.nextDouble() * 5, paint);
                },
              ),
            );
          },
        ),
      ),
    );
    
    // Remove explosion component after particle lifespan
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!isRemoved) {
        removeFromParent();
      }
    });
  }
}
