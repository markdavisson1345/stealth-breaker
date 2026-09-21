import 'package:flutter/material.dart';

import '../models/specialty_brick_info.dart';
import '../theme/stealth_theme.dart';

class SpecialtyBrickVisual extends StatelessWidget {
  const SpecialtyBrickVisual({
    super.key,
    required this.info,
    this.width = 64,
  });

  final SpecialtyBrickInfo info;
  final double width;

  @override
  Widget build(BuildContext context) {
    final color = switch (info.sampleHitPoints) {
      1 => StealthColors.red,
      2 => const Color(0xFFFFA54B),
      3 => StealthColors.gold,
      _ => StealthColors.textSecondary,
    };
    return Container(
      width: width,
      height: width * .48,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Stack(children: [
        Center(
          child: Text(
            '${info.sampleHitPoints}',
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 3,
          child: Text(
            info.symbol,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ]),
    );
  }
}
