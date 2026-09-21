import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/stealth_theme.dart';

class StealthLogo extends StatelessWidget {
  const StealthLogo({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Stealth Breaker',
        image: true,
        child: compact
            ? const SizedBox.square(
                dimension: 54, child: CustomPaint(painter: _LogoPainter()))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(
                    width: 132,
                    height: 70,
                    child: CustomPaint(painter: _LogoPainter())),
                const SizedBox(height: 6),
                Text('STEALTH BREAKER',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontSize: 22, letterSpacing: 2.8)),
              ]),
      );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final unit = math.min(size.width / 6.2, size.height / 3.2);
    final left = (size.width - unit * 5.4) / 2;
    final top = (size.height - unit * 2.5) / 2;
    final cyan = Paint()..color = StealthColors.cyan;
    final violet = Paint()
      ..color = StealthColors.violet.withOpacity(.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        if (row == 1 && col == 2) continue;
        final rect = Rect.fromLTWH(left + unit * (2.05 + col * 1.1),
            top + unit * (row * .9), unit, unit * .65);
        final r = RRect.fromRectAndRadius(rect, Radius.circular(unit * .10));
        canvas.drawRRect(r, row == 0 && col == 2 ? violet : cyan);
      }
    }
    final trajectory = Paint()
      ..color = StealthColors.cyan
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left, top + unit * 2.2),
        Offset(left + unit * 2.25, top + unit * 1.2), trajectory);
    canvas.drawCircle(Offset(left + unit * .75, top + unit * 1.86), unit * .32,
        Paint()..color = StealthColors.textPrimary);
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(left + unit * (5.15 + i * .18),
                  top + unit * (.92 + (i.isEven ? -.12 : .16))),
              width: unit * (.22 - i * .025),
              height: unit * (.16 - i * .018)),
          Paint()..color = StealthColors.violet.withOpacity(.8 - i * .14));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
