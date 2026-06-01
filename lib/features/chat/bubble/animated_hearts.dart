import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedHearts extends StatelessWidget {
  const AnimatedHearts({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -10,
      top: -12,
      child: Icon(
        Icons.favorite,
        color: Colors.white,
        size: 18,
      )
          .animate(onPlay: (controller) => controller.repeat())
          .moveY(
        begin: 0,
        end: -10,
        duration: 1000.ms,
      )
          .fadeIn()
          .fadeOut(),
    );
  }
}
