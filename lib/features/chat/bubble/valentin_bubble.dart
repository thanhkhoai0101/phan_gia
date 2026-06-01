import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';

import '../../../models/message_model.dart';

class ValentineBubble extends StatefulWidget {
  final bool isMe;
  final bool isMedia;
  final Widget contentWidget;
  final MessageModel message;

  const ValentineBubble({
    super.key,
    required this.isMe,
    required this.contentWidget,
    required this.isMedia,
    required this.message,
  });

  @override
  State<ValentineBubble> createState() => _ValentineBubbleState();
}

class _ValentineBubbleState extends State<ValentineBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 26),

      child: Align(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,

        child: Stack(
          clipBehavior: Clip.none,
          children: [
            /// TIM BAY
            ...List.generate(
              18,
              (index) => FloatingHeart(
                controller: controller,
                index: index,
                isMe: widget.isMe,
              ),
            ),

            Container(
              padding: widget.isMedia
                  ? const EdgeInsets.all(10)
                  : const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),

              decoration: BoxDecoration(
                /// gradient hồng
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFB3D7), Color(0xFFFF5FA8)],
                ),

                borderRadius: BorderRadius.circular(8),

                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5FA8).withOpacity(0.35),

                    blurRadius: 30,
                    spreadRadius: 3,
                    offset: const Offset(0, 12),
                  ),

                  BoxShadow(
                    color: Colors.white.withOpacity(0.15),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),

              child: Column(
                crossAxisAlignment: widget.isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  widget.contentWidget,
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(widget.message.timestamp),
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
            ),

            /// ICON TIM
            Positioned(
              top: -65,
              right: widget.isMe ? -20 : null,
              left: widget.isMe ? null : -30,

              child: AnimatedBuilder(
                animation: controller,

                builder: (context, child) {
                  final bounce = sin(controller.value * pi * 2) * 5;

                  final scale = 1 + (sin(controller.value * pi * 2) * 0.03);

                  return Transform.translate(
                    offset: Offset(0, bounce),

                    child: Transform.scale(scale: scale, child: child),
                  );
                },

                child: Container(
                  width: 92,
                  height: 92,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,

                    boxShadow: [
                      /// glow hồng
                      BoxShadow(
                        color: const Color(0xFFFF69B4).withOpacity(0.45),

                        blurRadius: 35,
                        spreadRadius: 4,
                      ),

                      /// glow trắng
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),

                  child: SvgPicture.asset(
                    'assets/images/valungtung.svg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TIM BAY
class FloatingHeart extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final bool isMe;

  const FloatingHeart({
    super.key,
    required this.controller,
    required this.index,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final random = Random(index);

    final startX = random.nextDouble() * 140;

    final size = 14 + random.nextDouble() * 18;

    final speed = 0.45 + random.nextDouble() * 0.5;

    return AnimatedBuilder(
      animation: controller,

      builder: (context, child) {
        double progress = ((controller.value * speed) + (index * 0.08)) % 1;

        final opacity = (1 - progress).clamp(0, 1);

        return Positioned(
          right: isMe ? startX + sin(progress * pi * 2) * 10 : null,

          left: isMe ? null : startX + sin(progress * pi * 2) * 10,

          top: -10 - (progress * 170),

          child: Opacity(
            opacity: opacity * 0.9,

            child: Transform.scale(
              scale: 0.5 + ((1 - progress) * 0.7),

              child: Transform.rotate(
                angle: sin(progress * pi * 2) * 0.2,

                child: SvgPicture.asset(
                  'assets/images/valinhtinh.svg',

                  width: size,
                  height: size,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// TAIL CUSTOM
