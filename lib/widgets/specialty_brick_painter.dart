import 'dart:math';
import 'dart:ui';

import '../models/brick.dart';

void paintSpecialtyTreatment(
  Canvas canvas,
  Rect rect,
  BrickSpecialType type, {
  required Color ink,
}) {
  final border = Paint()
    ..color = ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = type == BrickSpecialType.reinforced ? 2.6 : 1.8;
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(4)),
    border,
  );

  final center = rect.center;
  final unit = rect.shortestSide;
  switch (type) {
    case BrickSpecialType.explosive:
      final hazard = Paint()
        ..color = ink
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final angle = i * 3.141592653589793 / 4;
        final inner = Offset(
          center.dx + cos(angle) * unit * .16,
          center.dy + sin(angle) * unit * .16,
        );
        final outer = Offset(
          center.dx + cos(angle) * unit * .34,
          center.dy + sin(angle) * unit * .34,
        );
        canvas.drawLine(inner, outer, hazard);
      }
      canvas.drawCircle(center, unit * .12, Paint()..color = ink);
      break;
    case BrickSpecialType.split:
      final path = Path()
        ..moveTo(center.dx, rect.bottom - 4)
        ..lineTo(center.dx, center.dy)
        ..lineTo(center.dx - unit * .24, rect.top + 4)
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + unit * .24, rect.top + 4);
      canvas.drawPath(path, border..strokeWidth = 2.2);
      break;
    case BrickSpecialType.reinforced:
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(5), const Radius.circular(2)),
        border,
      );
      canvas.drawLine(rect.topLeft + const Offset(5, 5),
          rect.bottomRight - const Offset(5, 5), border..strokeWidth = 1.2);
      canvas.drawLine(rect.topRight + const Offset(-5, 5),
          rect.bottomLeft + const Offset(5, -5), border);
      break;
    case BrickSpecialType.bonus:
      _drawText(canvas, rect, '★', ink, unit * .68);
      break;
    case BrickSpecialType.extraShot:
      _drawText(canvas, rect, '+1', ink, unit * .58);
      break;
    case BrickSpecialType.none:
      break;
  }
}

void _drawText(Canvas canvas, Rect rect, String text, Color color, double size) {
  final paragraph = (ParagraphBuilder(ParagraphStyle(
    textAlign: TextAlign.center,
    fontSize: size,
    fontWeight: FontWeight.w800,
  ))
        ..pushStyle(TextStyle(color: color, fontWeight: FontWeight.w800))
        ..addText(text))
      .build()
    ..layout(ParagraphConstraints(width: rect.width));
  canvas.drawParagraph(
    paragraph,
    Offset(rect.left, rect.center.dy - paragraph.height / 2),
  );
}
