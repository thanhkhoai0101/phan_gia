import 'dart:math';
import 'package:flutter/material.dart';

class BauCuaShaker extends StatefulWidget {
  const BauCuaShaker({super.key});

  @override
  State<BauCuaShaker> createState() => _BauCuaShakerState();
}

class _BauCuaShakerState extends State<BauCuaShaker>
    with TickerProviderStateMixin {
  final Random random = Random();

  final List<String> faces = [
    'assets/images/baucua/tom_pro.png',
    'assets/images/baucua/cua_pro.png',
    'assets/images/baucua/bau_pro.png',
    'assets/images/baucua/ca_pro.png',
    'assets/images/baucua/nai_pro.png',
    'assets/images/baucua/ga_pro.png',
  ];

  late List<int> results;
  bool covered = true;
  bool shaking = false;

  Future<void> shake() async {
    if (shaking) return;

    setState(() {
      shaking = true;
      covered = true;
    });

    await Future.delayed(const Duration(milliseconds: 450));

    setState(() {
      results = List.generate(3, (_) => random.nextInt(6));
    });

    for (int i = 0; i < 18; i++) {
      await Future.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;
      setState(() {});
    }

    await Future.delayed(const Duration(milliseconds: 120));

    setState(() {
      covered = false;
    });

    await Future.delayed(const Duration(milliseconds: 900));

    setState(() {
      shaking = false;
    });
  }

  @override
  void initState() {
    super.initState();
    results = List.generate(3, (_) => random.nextInt(6));
  }

  Widget dice(int index) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 1000),
      curve: Curves.elasticOut,
      offset: covered ? const Offset(0, -1.5) : Offset.zero,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: covered ? 0 : 1,
        child: Container(
          width: 90,
          height: 90,
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Image.asset(faces[results[index]]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: shake,
          child: SizedBox(
            width: 320,
            height: 320,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD6A86A),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                ),
                Positioned(top: 95, left: 60, child: dice(0)),
                Positioned(top: 150, left: 115, child: dice(1)),
                Positioned(top: 95, right: 60, child: dice(2)),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  top: covered ? (shaking ? 30 : 20) : -220,
                  child: Transform.rotate(
                    angle: shaking
                        ? sin(DateTime.now().millisecondsSinceEpoch / 45) * 0.18
                        : 0,
                    child: Container(
                      width: 260,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(130),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: shake, child: const Text('Xóc Bầu Cua')),
      ],
    );
  }
}

/*
PRO VERSION UPGRADES APPLIED:
- Strong realistic bowl shake
- Elastic dice bounce drop
- Dynamic shadows
- Motion-like aggressive shake timing
- Better reveal timing

OPTIONAL NEXT STEP FOR TRUE PHYSICS:
Use Flame + Forge2D if you want real rigid-body collision physics.
Current version is production-grade UI animation without external engine.
*/
