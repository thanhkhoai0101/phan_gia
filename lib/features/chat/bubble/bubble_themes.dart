import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'bubble_theme_data.dart';
import 'bubble_types.dart';

class BubbleThemes {
  static final themes = [
    ocean,
    love,
    frog,
    neon,
    fire,
    cloud,
    cat,
    gaming,
    sunset,
    messenger,
  ];

  static final ocean = BubbleThemeData(
    gradient: const LinearGradient(
      colors: [
        Color(0xFF4FACFE),
        Color(0xFF00F2FE),
      ],
    ),
    icon: FontAwesomeIcons.water,
    iconColor: Colors.white,
    glowColor: Colors.cyan,
    textColor: Colors.white,
    animationType: BubbleAnimationType.floating,
    showGlow: true,
    showHearts: false,
    showTail: true,
    showWaterEffect: true,
  );

  static final love = BubbleThemeData(
    gradient: const LinearGradient(
      colors: [
        Color(0xFFFF758C),
        Color(0xFFFF7EB3),
      ],
    ),
    icon: FontAwesomeIcons.heart,
    iconColor: Colors.white,
    glowColor: Colors.pink,
    textColor: Colors.white,
    animationType: BubbleAnimationType.bounce,
    showGlow: true,
    showHearts: true,
    showTail: true,
    showWaterEffect: false,
  );

  static final frog = BubbleThemeData(
    gradient: const LinearGradient(
      colors: [
        Color(0xFF56AB2F),
        Color(0xFFA8E063),
      ],
    ),
    icon: FontAwesomeIcons.frog,
    iconColor: Colors.white,
    glowColor: Colors.green,
    textColor: Colors.white,
    animationType: BubbleAnimationType.bounce,
    showGlow: true,
    showHearts: false,
    showTail: true,
    showWaterEffect: false,
  );

  static final neon = BubbleThemeData(
    gradient: const LinearGradient(
      colors: [
        Color(0xFF8E2DE2),
        Color(0xFF4A00E0),
      ],
    ),
    icon: FontAwesomeIcons.bolt,
    iconColor: Colors.white,
    glowColor: Colors.purpleAccent,
    textColor: Colors.white,
    animationType: BubbleAnimationType.pulse,
    showGlow: true,
    showHearts: false,
    showTail: true,
    showWaterEffect: false,
  );

  static final fire = BubbleThemeData(
    gradient: const LinearGradient(
      colors: [
        Color(0xFFFF512F),
        Color(0xFFF09819),
      ],
    ),
    icon: FontAwesomeIcons.fire,
    iconColor: Colors.white,
    glowColor: Colors.orange,
    textColor: Colors.white,
    animationType: BubbleAnimationType.shake,
    showGlow: true,
    showHearts: false,
    showTail: true,
    showWaterEffect: false,
  );

  static final cloud = BubbleThemeData(
    gradient: const LinearGradient(
      colors: [
        Color(0xFFE0EAFC),
        Color(0xFFCFDEF3),
      ],
    ),
    icon: FontAwesomeIcons.cloud,
    iconColor: Colors.blueGrey,
    glowColor: Colors.white,
    textColor: Colors.black87,
    animationType: BubbleAnimationType.floating,
    showGlow: false,
    showHearts: false,
    showTail: true,
    showWaterEffect: true,
  );

  static final cat = BubbleThemeData(
    gradient: const LinearGradient(
      colors: [
        Color(0xFFFFD194),
        Color(0xFFD1913C),
      ],
    ),
    icon: FontAwesomeIcons.cat,
    iconColor: Colors.white,
    glowColor: Colors.orangeAccent,
    textColor: Colors.white,
    animationType: BubbleAnimationType.bounce,
    showGlow: true,
    showHearts: false,
    showTail: true,
    showWaterEffect: false,
  );

  static final gaming = BubbleThemeData(
    gradient: const LinearGradient(
      colors: [
        Color(0xFFFC466B),
        Color(0xFF3F5EFB),
      ],
    ),
    icon: FontAwesomeIcons.gamepad,
    iconColor: Colors.white,
    glowColor: Colors.blueAccent,
    textColor: Colors.white,
    animationType: BubbleAnimationType.pulse,
    showGlow: true,
    showHearts: false,
    showTail: true,
    showWaterEffect: false,
  );

  static final sunset = BubbleThemeData(
    gradient: const LinearGradient(
      colors: [
        Color(0xFFee0979),
        Color(0xFFff6a00),
      ],
    ),
    icon: FontAwesomeIcons.sun,
    iconColor: Colors.white,
    glowColor: Colors.deepOrange,
    textColor: Colors.white,
    animationType: BubbleAnimationType.floating,
    showGlow: true,
    showHearts: false,
    showTail: true,
    showWaterEffect: false,
  );

  static final messenger = BubbleThemeData(
    gradient: const LinearGradient(
      colors: [
        Color(0xFF0093E9),
        Color(0xFF80D0C7),
      ],
    ),
    icon: FontAwesomeIcons.facebookMessenger,
    iconColor: Colors.white,
    glowColor: Colors.blue,
    textColor: Colors.white,
    animationType: BubbleAnimationType.none,
    showGlow: false,
    showHearts: false,
    showTail: true,
    showWaterEffect: false,
  );
}
