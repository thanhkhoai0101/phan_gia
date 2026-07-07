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
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: myBet > 0 ? Colors.amberAccent : Colors.white10,
            width: myBet > 0 ? 2 : 1,
          ),
          boxShadow: myBet > 0
              ? [BoxShadow(color: Colors.amberAccent.withOpacity(0.2), blurRadius: 10, spreadRadius: 1)]
              : [],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image Background
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: _buildMascotImageBackground(index),
            ),
            
            // Gradient Overlay for Text Readability
            if (totalBet > 0 || myBet > 0)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),

            // Bet Info Overlay
            if (totalBet > 0 || myBet > 0)
              Positioned(
                bottom: 4,
                left: 2,
                right: 2,
                child: _buildBetInfo(totalBet, myBet),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMascotImageBackground(int index) {
    return Image.asset(
      _getAssetPath(index),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: mascotColor.withOpacity(0.2),
        child: Center(
          child: Icon(_getMascotIcon(index), color: mascotColor, size: 40),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (total > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.5), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 10),
                const SizedBox(width: 4),
                Text(
                  total.toString(),
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        if (mine > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Bạn: $mine',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
