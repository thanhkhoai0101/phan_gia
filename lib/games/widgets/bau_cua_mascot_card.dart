import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class BauCuaMascotCard extends StatelessWidget {
  final int index;
  final String name;
  final int totalBet;
  final int myBet;
  final bool canBet;
  final VoidCallback onTap;
  final Color mascotColor;

  const BauCuaMascotCard({
    Key? key,
    required this.index,
    required this.name,
    required this.totalBet,
    required this.myBet,
    required this.canBet,
    required this.onTap,
    required this.mascotColor,
  }) : super(key: key);

  String _getAssetPath(int index) {
    const String base = 'assets/images/baucua/';
    switch (index) {
      case 0: return '${base}nai_pro.png';
      case 1: return '${base}bau_pro.png';
      case 2: return '${base}ga_pro.png';
      case 3: return '${base}tom_pro.png';
      case 4: return '${base}cua_pro.png';
      case 5: return '${base}ca_pro.png';
      default: return '${base}nai_pro.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: canBet ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: myBet > 0 ? Colors.amberAccent : Colors.white10,
            width: myBet > 0 ? 2 : 1,
          ),
          boxShadow: myBet > 0
              ? [BoxShadow(color: Colors.amberAccent.withOpacity(0.1), blurRadius: 15, spreadRadius: 2)]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              flex: 3,
              child: _buildMascotImage(index),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              flex: 2,
              child: _buildBetInfo(totalBet, myBet),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMascotImage(int index) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white10,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          _getAssetPath(index),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Center(
            child: Icon(_getMascotIcon(index), color: mascotColor, size: 30),
          ),
        ),
      ),
    );
  }

  IconData _getMascotIcon(int index) {
    switch (index) {
      case 0: return Icons.eco;
      case 1: return Icons.wine_bar;
      case 2: return Icons.egg;
      case 3: return Icons.bug_report;
      case 4: return Icons.vaping_rooms;
      case 5: return Icons.tsunami;
      default: return Icons.help_outline;
    }
  }

  Widget _buildBetInfo(int total, int mine) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 10),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    total.toString(),
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (mine > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Bạn: $mine',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
