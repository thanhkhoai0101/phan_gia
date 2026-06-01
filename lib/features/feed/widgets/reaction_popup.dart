import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Định nghĩa tất cả các loại cảm xúc
class ReactionConfig {
  static const Map<String, String> emojis = {
    'like': '👍',
    'love': '❤️',
    'haha': '😆',
    'wow': '😮',
    'sad': '😢',
    'angry': '😠',
  };

  static const Map<String, String> labels = {
    'like': 'Thích',
    'love': 'Yêu thích',
    'haha': 'Haha',
    'wow': 'Wow',
    'sad': 'Buồn',
    'angry': 'Phẫn nộ',
  };

  static const Map<String, Color> colors = {
    'like': Color(0xFF1877F2),
    'love': Color(0xFFFF3B30),
    'haha': Color(0xFFFFAB00),
    'wow': Color(0xFFFFAB00),
    'sad': Color(0xFFFFAB00),
    'angry': Color(0xFFFF6B00),
  };

  static String emoji(String type) => emojis[type] ?? '👍';
  static String label(String type) => labels[type] ?? 'Thích';
  static Color color(String type) => colors[type] ?? const Color(0xFF1877F2);
}

class ReactionPopup extends StatefulWidget {
  final Function(String reactionType) onReactionSelected;
  final VoidCallback onClose;

  const ReactionPopup({
    Key? key,
    required this.onReactionSelected,
    required this.onClose,
  }) : super(key: key);

  @override
  State<ReactionPopup> createState() => _ReactionPopupState();
}

class _ReactionPopupState extends State<ReactionPopup>
    with TickerProviderStateMixin {
  late AnimationController _containerController;
  late Animation<double> _containerScale;
  late Animation<double> _containerOpacity;

  final List<AnimationController> _itemControllers = [];
  final List<Animation<double>> _itemScales = [];
  String? _hoveredReaction;

  static const List<String> reactionOrder = [
    'like', 'love', 'haha', 'wow', 'sad', 'angry'
  ];

  @override
  void initState() {
    super.initState();
    _containerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _containerScale = CurvedAnimation(
      parent: _containerController,
      curve: Curves.easeOutBack,
    );
    _containerOpacity = CurvedAnimation(
      parent: _containerController,
      curve: Curves.easeIn,
    );

    for (int i = 0; i < reactionOrder.length; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      );
      _itemControllers.add(ctrl);
      _itemScales.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOutBack));
      // Stagger entry
      Future.delayed(Duration(milliseconds: i * 30), () {
        if (mounted) ctrl.forward();
      });
    }

    _containerController.forward();
  }

  @override
  void dispose() {
    _containerController.dispose();
    for (var c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _containerOpacity,
      child: ScaleTransition(
        scale: _containerScale,
        alignment: Alignment.bottomLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(reactionOrder.length, (index) {
              final type = reactionOrder[index];
              final isHovered = _hoveredReaction == type;
              return ScaleTransition(
                scale: _itemScales[index],
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hoveredReaction = type),
                  onExit: (_) => setState(() => _hoveredReaction = null),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onReactionSelected(type);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.all(4),
                      transform: isHovered
                          ? (Matrix4.identity()..scale(1.25)..translate(0.0, -4.0))
                          : Matrix4.identity(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ReactionConfig.emoji(type),
                            style: const TextStyle(fontSize: 30),
                          ),
                          if (isHovered)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                ReactionConfig.label(type),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
