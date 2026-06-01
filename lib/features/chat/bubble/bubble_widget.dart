import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'animated_hearts.dart';
import 'bubble_tail_painter.dart';
import 'bubble_theme_data.dart';
import 'bubble_types.dart';

class BubbleWidget extends StatelessWidget {
  final String text;
  final BubbleThemeData theme;
  final bool isMe;

  const BubbleWidget({
    super.key,
    required this.text,
    required this.theme,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget bubble = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: const BoxConstraints(
            maxWidth: 300,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            gradient: theme.gradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: theme.showGlow
                ? [
              BoxShadow(
                color: theme.glowColor.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ]
                : [],
          ),
          child: Stack(
            children: [
              if (theme.showWaterEffect)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.08,
                    child: Transform.rotate(
                      angle: pi / 12,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              Text(
                text,
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        Positioned(
          top: -20,
          left: isMe? 2 : null,
          right: isMe ? null : 2,
          child: Icon(
          theme.icon,
          size: 25,
          color: theme.iconColor,
        ),),
        if (theme.showTail)
          Positioned(
            bottom: -8,
            left: isMe ? null : 16,
            right: isMe ? 16 : null,
            child: CustomPaint(
              size: const Size(16, 12),
              painter: BubbleTailPainter(
                Colors.white.withOpacity(0.3),
              ),
            ),
          ),

        if (theme.showHearts)
          const AnimatedHearts(),
      ],
    );

    switch (theme.animationType) {
      case BubbleAnimationType.bounce:
        bubble = bubble
            .animate(onPlay: (controller) => controller.repeat())
            .moveY(
          begin: 0,
          end: -4,
          duration: 1200.ms,
        );

        break;

      case BubbleAnimationType.shake:
        bubble = bubble
            .animate(onPlay: (controller) => controller.repeat())
            .shake(
          duration: 1200.ms,
        );

        break;

      case BubbleAnimationType.floating:
        bubble = bubble
            .animate(onPlay: (controller) => controller.repeat())
            .moveY(
          begin: 0,
          end: -6,
          duration: 2000.ms,
        );

        break;

      case BubbleAnimationType.pulse:
        bubble = bubble
            .animate(onPlay: (controller) => controller.repeat())
            .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.03, 1.03),
          duration: 1200.ms,
        );

        break;

      case BubbleAnimationType.none:
        break;
    }

    return Align(
      alignment:
      isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        child: bubble,
      ),
    );
  }
}
