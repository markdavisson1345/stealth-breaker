import 'package:flutter/material.dart';

import '../models/specialty_brick_info.dart';
import '../theme/stealth_theme.dart';
import 'specialty_brick_painter.dart';

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
      child: CustomPaint(
        painter: _SpecialtySamplePainter(info),
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 5, top: 2),
            child: Text('${info.sampleHitPoints}',
                style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 9,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}

class _SpecialtySamplePainter extends CustomPainter {
  const _SpecialtySamplePainter(this.info);
  final SpecialtyBrickInfo info;

  @override
  void paint(Canvas canvas, Size size) => paintSpecialtyTreatment(
        canvas,
        Offset.zero & size,
        info.type,
        ink: const Color(0xFF111827),
      );

  @override
  bool shouldRepaint(covariant _SpecialtySamplePainter oldDelegate) =>
      oldDelegate.info.type != info.type;
}
