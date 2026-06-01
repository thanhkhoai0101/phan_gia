import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'bubble_types.dart';

class BubbleThemeData {
  final Gradient gradient;
  final IconData icon;
  final Color iconColor;
  final Color glowColor;
  final Color textColor;

  final BubbleAnimationType animationType;

  final bool showGlow;
  final bool showHearts;
  final bool showTail;
  final bool showWaterEffect;

  BubbleThemeData({
    required this.gradient,
    required this.icon,
    required this.iconColor,
    required this.glowColor,
    required this.textColor,
    required this.animationType,
    required this.showGlow,
    required this.showHearts,
    required this.showTail,
    required this.showWaterEffect,
  });
}
