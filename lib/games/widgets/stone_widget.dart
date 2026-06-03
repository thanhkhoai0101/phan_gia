import 'package:flutter/material.dart';

class StoneWidget extends StatelessWidget {
  final int value;
  final bool isLastMove;

  const StoneWidget({
    super.key,
    required this.value,
    this.isLastMove = false,
  });

  @override
  Widget build(BuildContext context) {
    if (value == 0) {
      return const SizedBox();
    }

    return Center(
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
          value == 1
              ? Colors.black
              : Colors.white,
          border: Border.all(
            color: Colors.black26,
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 4,
              offset: Offset(1, 2),
              color: Colors.black26,
            ),
          ],
        ),
        child: isLastMove
            ? Center(
          child: Container(
            width: 6,
            height: 6,
            decoration:
            const BoxDecoration(
              color: Colors.red,
              shape:
              BoxShape.circle,
            ),
          ),
        )
            : null,
      ),
    );
  }
}
