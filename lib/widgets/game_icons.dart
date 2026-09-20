import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/stealth_theme.dart';

enum GameIconType {
  preview,
  stealth,
  shots,
  streak,
  combo,
  accuracy,
  achievement,
  reward,
  newBest,
  locked,
}

class GameIcon extends StatelessWidget {
  const GameIcon(this.type,
      {super.key, this.size = 28, this.color = StealthColors.cyan});
  final GameIconType type;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _GameIconPainter(type, color),
      );
}

class _GameIconPainter extends CustomPainter {
  const _GameIconPainter(this.type, this.color);
  final GameIconType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, s * .065)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color.withValues(alpha: .18);
    Rect brick(double x, double y, [double w = .38, double h = .22]) =>
        Rect.fromLTWH(s * x, s * y, s * w, s * h);
    void drawBrick(Rect rect, {bool faded = false}) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(s * .045)),
          faded
              ? (Paint()
                ..color = color.withValues(alpha: .34)
                ..style = PaintingStyle.stroke
                ..strokeWidth = line.strokeWidth)
              : fill);
      if (!faded) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(s * .045)), line);
      }
    }

    switch (type) {
      case GameIconType.preview:
        drawBrick(brick(.10, .22));
        drawBrick(brick(.52, .22), faded: true);
        drawBrick(brick(.31, .50), faded: true);
        canvas.drawArc(
            Rect.fromCircle(center: Offset(s * .75, s * .70), radius: s * .18),
            -math.pi / 2,
            math.pi * 1.5,
            false,
            line);
        break;
      case GameIconType.stealth:
        drawBrick(brick(.12, .34, .52, .30), faded: true);
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(Offset(s * (.72 + i * .08), s * (.39 + i * .10)),
              s * (.045 - i * .007), line);
        }
        break;
      case GameIconType.shots:
        canvas.drawCircle(Offset(s * .20, s * .76), s * .11, fill);
        canvas.drawCircle(Offset(s * .20, s * .76), s * .11, line);
        final p = Path()
          ..moveTo(s * .28, s * .68)
          ..lineTo(s * .78, s * .22)
          ..lineTo(s * .90, s * .40);
        canvas.drawPath(p, line);
        break;
      case GameIconType.streak:
        for (var i = 0; i < 3; i++) {
          drawBrick(brick(.10 + i * .25, .66 - i * .20, .22, .16));
        }
        break;
      case GameIconType.combo:
        final p = Path()
          ..moveTo(s * .12, s * .82)
          ..lineTo(s * .44, s * .34)
          ..lineTo(s * .72, s * .62)
          ..lineTo(s * .90, s * .24);
        canvas.drawPath(p, line);
        for (final o in const [Offset(.44, .34), Offset(.72, .62)]) {
          canvas.drawCircle(Offset(s * o.dx, s * o.dy), s * .07, fill);
          canvas.drawCircle(Offset(s * o.dx, s * o.dy), s * .07, line);
        }
        break;
      case GameIconType.accuracy:
        drawBrick(brick(.50, .26, .38, .28));
        canvas.drawCircle(Offset(s * .43, s * .55), s * .10, fill);
        canvas.drawCircle(Offset(s * .43, s * .55), s * .10, line);
        canvas.drawLine(
            Offset(s * .12, s * .84), Offset(s * .36, s * .62), line);
        break;
      case GameIconType.achievement:
      case GameIconType.reward:
      case GameIconType.newBest:
        final badge = Path()
          ..moveTo(s * .50, s * .08)
          ..lineTo(s * .88, s * .28)
          ..lineTo(s * .82, s * .72)
          ..lineTo(s * .50, s * .92)
          ..lineTo(s * .18, s * .72)
          ..lineTo(s * .12, s * .28)
          ..close();
        canvas.drawPath(badge, fill);
        canvas.drawPath(badge, line);
        drawBrick(brick(.31, .37, .38, .24));
        if (type == GameIconType.newBest) {
          canvas.drawCircle(Offset(s * .72, s * .25), s * .06, line);
        }
        break;
      case GameIconType.locked:
        drawBrick(brick(.18, .46, .64, .38), faded: true);
        canvas.drawArc(Rect.fromLTWH(s * .31, s * .13, s * .38, s * .50),
            math.pi, math.pi, false, line);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _GameIconPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
