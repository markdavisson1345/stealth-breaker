import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../theme/stealth_theme.dart';
import '../widgets/stealth_components.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int stage = 0;
  Offset? aim;
  bool fired = false;

  @override
  void initState() {
    super.initState();
    widget.controller.analytics.event('tutorialStarted');
  }

  @override
  Widget build(BuildContext context) {
    final text = switch (stage) {
      0 =>
        'Some purple-outlined bricks are stealth bricks. Remember their positions.',
      1 =>
        'The preview ends and stealth bricks disappear—but they are still there.',
      2 => 'Drag upward from the ball to aim. Release to fire.',
      _ => 'Perfect memory! Hidden bricks flash purple when you find them.',
    };
    return Scaffold(
        body: StealthScreenBackground(
            child: Column(children: [
      const StealthHeader(
          title: 'How to Play', subtitle: 'See → Remember → Aim → Break'),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: StealthCard(
              accent: stage <= 1 ? StealthColors.violet : StealthColors.cyan,
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium))),
      Expanded(
          child: LayoutBuilder(
              builder: (_, box) => GestureDetector(
                    onPanStart: stage == 2
                        ? (d) => setState(() => aim = d.localPosition)
                        : null,
                    onPanUpdate: stage == 2
                        ? (d) => setState(() => aim = d.localPosition)
                        : null,
                    onPanEnd: stage == 2
                        ? (_) => setState(() {
                              fired = true;
                              stage = 3;
                              aim = null;
                            })
                        : null,
                    child: CustomPaint(
                        size: Size(box.maxWidth, box.maxHeight),
                        painter: _TutorialPainter(
                            stage: stage, aim: aim, fired: fired)),
                  ))),
      Padding(
          padding: const EdgeInsets.all(16),
          child: StealthButton(
              onPressed: stage == 2
                  ? null
                  : () async {
                      if (stage < 3) {
                        setState(() => stage++);
                      } else {
                        await widget.controller.setTutorialComplete(true);
                        widget.controller.analytics.event('tutorialCompleted');
                        if (!mounted) return;
                        Navigator.of(this.context).pop();
                      }
                    },
              label: stage == 3 ? 'Start Breaking' : 'Next',
              icon: stage == 3
                  ? Icons.play_arrow_rounded
                  : Icons.arrow_forward_rounded)),
    ])));
  }
}

class _TutorialPainter extends CustomPainter {
  _TutorialPainter({required this.stage, this.aim, required this.fired});
  final int stage;
  final Offset? aim;
  final bool fired;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = StealthColors.background);
    const cols = 6;
    const gap = 6.0;
    final width = (size.width - 40 - gap * (cols - 1)) / cols;
    final stealth = <int>{2, 9, 16};
    for (var i = 0; i < 18; i++) {
      if (i == 5 || i == 12) continue;
      final rect = Rect.fromLTWH(20 + (i % cols) * (width + gap),
          38 + (i ~/ cols) * (width * .5 + gap), width, width * .5);
      final hidden =
          stage >= 1 && stealth.contains(i) && !(stage == 3 && i == 16);
      if (!hidden) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(5)),
            Paint()
              ..color =
                  i % 3 == 0 ? const Color(0xFFFFA54B) : StealthColors.red);
        if (stealth.contains(i)) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(5)),
              Paint()
                ..color = StealthColors.violet
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3);
        }
      }
    }
    final ball = Offset(size.width / 2, size.height - 52);
    final target = aim ?? Offset(size.width * .72, size.height * .35);
    if (stage >= 2 && !fired) {
      final path = ui.Path()
        ..moveTo(ball.dx, ball.dy)
        ..lineTo(target.dx, target.dy);
      canvas.drawPath(
          path,
          Paint()
            ..color = StealthColors.cyan.withValues(alpha: .75)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);
    }
    canvas.drawCircle(
        ball, 7, Paint()..color = StealthColors.cyan.withValues(alpha: .16));
    canvas.drawCircle(ball, 4.5, Paint()..color = StealthColors.textPrimary);
  }

  @override
  bool shouldRepaint(covariant _TutorialPainter old) =>
      old.stage != stage || old.aim != aim || old.fired != fired;
}
