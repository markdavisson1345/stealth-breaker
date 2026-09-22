import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../game/systems/trajectory_predictor.dart';
import '../models/specialty_brick_info.dart';
import '../theme/stealth_theme.dart';
import '../widgets/playfield_frame.dart';
import '../widgets/specialty_brick_visual.dart';
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

  bool _trajectoryHitsTarget(Size size, Offset candidate) {
    final geometry = TutorialBoardGeometry(size);
    return TrajectoryPredictor.hitsTarget(
      launch: geometry.ball,
      aim: candidate,
      fieldSize: size,
      ballRadius: 4.5,
      target: geometry.brickRect(16),
      blockers: [
        for (var i = 0; i < 18; i++)
          if (i != 5 && i != 12 && i != 16) geometry.brickRect(i),
      ],
    );
  }

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
      3 => 'Perfect memory! Hidden bricks flash purple when you find them.',
      _ =>
        'Specialty bricks add new effects. Their outlined symbol identifies the effect.',
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
          child: stage == 4
              ? const SpecialtyBricksSection()
              : PlayfieldFrame(
              child: LayoutBuilder(
                  builder: (_, box) => GestureDetector(
                        onPanStart: stage == 2
                            ? (d) => setState(() => aim = d.localPosition)
                            : null,
                        onPanUpdate: stage == 2
                            ? (d) => setState(() => aim = d.localPosition)
                            : null,
                        onPanEnd: stage == 2
                            ? (_) {
                                final candidate = aim;
                                final hit = candidate != null &&
                                    _trajectoryHitsTarget(
                                      Size(box.maxWidth, box.maxHeight),
                                      candidate,
                                    );
                                setState(() {
                                  fired = hit;
                                  if (hit) stage = 3;
                                  aim = null;
                                });
                              }
                            : null,
                        child: CustomPaint(
                            size: Size(box.maxWidth, box.maxHeight),
                            painter: _TutorialPainter(
                                stage: stage, aim: aim, fired: fired)),
                      )))),
      Padding(
          padding: const EdgeInsets.all(16),
          child: StealthButton(
              onPressed: stage == 2
                  ? null
                  : () async {
                      if (stage < 4) {
                        setState(() => stage++);
                      } else {
                        await widget.controller.setTutorialComplete(true);
                        widget.controller.analytics.event('tutorialCompleted');
                        if (!mounted) return;
                        Navigator.of(this.context).pop(true);
                      }
                    },
              label: stage == 4 ? 'Start Breaking' : 'Next',
              icon: stage == 4
                  ? Icons.play_arrow_rounded
                  : Icons.arrow_forward_rounded)),
    ])));
  }
}

class SpecialtyBricksSection extends StatelessWidget {
  const SpecialtyBricksSection({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.separated(
            key: const ValueKey('specialty-bricks-section'),
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            itemCount: SpecialtyBrickCatalog.all.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final info = SpecialtyBrickCatalog.all[index];
              return StealthCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  SpecialtyBrickVisual(info: info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(info.name,
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(info.description,
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 2),
                        Text(
                          info.stealthNote,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: StealthColors.violet),
                        ),
                      ],
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
      );
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
    final geometry = TutorialBoardGeometry(size);
    final stealth = <int>{2, 9, 16};
    for (var i = 0; i < 18; i++) {
      if (i == 5 || i == 12) continue;
      final rect = geometry.brickRect(i);
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
    final ball = geometry.ball;
    final target = aim ?? Offset(size.width * .72, size.height * .35);
    if (stage >= 2 && !fired) {
      final path = ui.Path()
        ..moveTo(ball.dx, ball.dy)
        ..lineTo(target.dx, target.dy);
      canvas.drawPath(
          path,
          Paint()
            ..color = StealthColors.cyan.withOpacity(.75)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);
    }
    canvas.drawCircle(
        ball, 7, Paint()..color = StealthColors.cyan.withOpacity(.16));
    canvas.drawCircle(ball, 4.5, Paint()..color = StealthColors.textPrimary);
  }

  @override
  bool shouldRepaint(covariant _TutorialPainter old) =>
      old.stage != stage || old.aim != aim || old.fired != fired;
}

@visibleForTesting
class TutorialBoardGeometry {
  TutorialBoardGeometry(this.size)
      : brickWidth = (size.width - 40 - 6 * 5) / 6;

  final Size size;
  final double brickWidth;
  Offset get ball => Offset(size.width / 2, size.height - 52);
  Rect brickRect(int index) => Rect.fromLTWH(
        20 + (index % 6) * (brickWidth + 6),
        38 + (index ~/ 6) * (brickWidth * .5 + 6),
        brickWidth,
        brickWidth * .5,
      );
}
