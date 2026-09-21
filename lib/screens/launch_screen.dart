import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../services/audio_service.dart';
import '../theme/stealth_theme.dart';
import '../widgets/game_button.dart';
import 'achievements_screen.dart';
import 'daily_challenge_screen.dart';
import 'game_screen.dart';
import 'objectives_screen.dart';
import 'powers_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'tutorial_screen.dart';

class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key, required this.controller});
  final AppController controller;

  void _push(BuildContext context, Widget screen) => Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: StealthMotion.standard,
        pageBuilder: (_, animation, __) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: screen),
      ));

  Future<void> _play(BuildContext context) async {
    if (!controller.progress.tutorialComplete) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TutorialScreen(controller: controller)));
    }
    if (context.mounted) {
      final reservedPower = await controller.consumeEquippedPowerForLevel();
      if (!context.mounted) return;
      _push(
          context,
          GameScreen(
              controller: controller,
              level: controller.progress.highestLevel,
              reservedPower: reservedPower));
    }
  }

  @override
  Widget build(BuildContext context) {
    unawaited(controller.audio.playMusic(MusicTrack.menu));
    return Scaffold(
        body: Stack(children: [
      const Positioned.fill(child: CustomPaint(painter: _MenuScenePainter())),
      Positioned.fill(
          child: DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
            Colors.black.withOpacity(.40),
            const Color(0xE6080B14),
            const Color(0xFF030712)
          ])))),
      SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.visibility_off_rounded,
                                size: 62, color: Color(0xFFEF4444)),
                            Text('STEALTH',
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 5,
                                        shadows: const [
                                      Shadow(
                                          blurRadius: 10, color: Colors.black)
                                    ])),
                            Text('BREAKER',
                                style: Theme.of(context)
                                    .textTheme
                                    .displaySmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.w300,
                                        letterSpacing: 8,
                                        color: const Color(0xFFCBD5E1),
                                        shadows: const [
                                      Shadow(
                                          blurRadius: 10, color: Colors.black)
                                    ])),
                            const Text('See → Remember → Aim → Break',
                                style: TextStyle(color: Color(0xFF94A3B8))),
                            const SizedBox(height: 28),
                            GameButton(
                                label:
                                    'Play — Level ${controller.progress.highestLevel}',
                                icon: Icons.play_arrow_rounded,
                                onPressed: () => _play(context)),
                            const SizedBox(height: 10),
                            GameButton(
                                label: 'Daily Challenge',
                                icon: Icons.today_rounded,
                                onPressed: () => _push(
                                    context,
                                    DailyChallengeScreen(
                                        controller: controller))),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                  child: _smallButton(
                                      context,
                                      'Achievements\n${controller.completedAchievementCount}/${controller.totalAchievementTiers}',
                                      Icons.emoji_events,
                                      () => _push(
                                          context,
                                          AchievementsScreen(
                                              controller: controller)))),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _smallButton(
                                      context,
                                      'Powers\n${controller.progress.achievementPoints} AP',
                                      Icons.bolt,
                                      () => _push(
                                          context,
                                          PowersScreen(
                                              controller: controller)))),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                  child: _smallButton(
                                      context,
                                      'Objectives',
                                      Icons.task_alt,
                                      () => _push(
                                          context,
                                          ObjectivesScreen(
                                              controller: controller)))),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _smallButton(
                                      context,
                                      'Stats',
                                      Icons.bar_chart,
                                      () => _push(
                                          context,
                                          StatsScreen(
                                              controller: controller)))),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _smallButton(
                                      context,
                                      'Settings',
                                      Icons.settings,
                                      () => _push(
                                          context,
                                          SettingsScreen(
                                              controller: controller)))),
                            ]),
                            const SizedBox(height: 18),
                            Text(
                                'High score ${controller.progress.highScore}  •  Stars ${controller.progress.totalStars}',
                                style:
                                    const TextStyle(color: Color(0xFF94A3B8))),
                          ]))))),
    ]));
  }

  Widget _smallButton(BuildContext context, String label, IconData icon,
          VoidCallback onTap) =>
      OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16),
          const SizedBox(width: 2),
          Flexible(
              child: Text(label,
                  maxLines: label.contains('\n') ? 2 : 1,
                  softWrap: label.contains('\n'),
                  overflow: TextOverflow.fade,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12))),
        ]),
      );
}

class _MenuScenePainter extends CustomPainter {
  const _MenuScenePainter();
  @override
  void paint(Canvas canvas, Size size) {
    const columns = 8;
    const gap = 5.0;
    final fieldWidth = (size.width - 34).clamp(240.0, 440.0).toDouble();
    final brickWidth =
        ((fieldWidth - gap * 7) / 8).clamp(24.0, 52.0).toDouble();
    final brickHeight = brickWidth * .48;
    final left = (size.width - (brickWidth * columns + gap * 7)) / 2;
    const hidden = {3, 12, 22, 35, 41};
    const empty = {5, 9, 18, 30, 38, 46};
    for (var i = 0; i < 48; i++) {
      if (empty.contains(i)) continue;
      final rect = Rect.fromLTWH(left + (i % 8) * (brickWidth + gap),
          96 + (i ~/ 8) * (brickHeight + gap), brickWidth, brickHeight);
      final hp = i % 7 == 0 || i % 11 == 0 ? 3 : (i % 3 == 0 ? 2 : 1);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      if (hidden.contains(i)) {
        canvas.drawRRect(
            rrect,
            Paint()
              ..color = StealthColors.violet.withOpacity(.56)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5);
      } else {
        final color = hp == 3
            ? StealthColors.gold
            : hp == 2
                ? const Color(0xFFFFA54B)
                : StealthColors.red;
        canvas.drawRRect(rrect, Paint()..color = color.withOpacity(.72));
      }
    }
    final ball = Offset(size.width / 2, size.height * .44);
    final path = ui.Path()
      ..moveTo(ball.dx, ball.dy)
      ..lineTo(size.width * .80, size.height * .27)
      ..lineTo(size.width * .68, size.height * .19);
    canvas.drawPath(
        path,
        Paint()
          ..color = StealthColors.cyan.withOpacity(.70)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke);
    canvas.drawCircle(
        ball, 7, Paint()..color = StealthColors.cyan.withOpacity(.12));
    canvas.drawCircle(ball, 4, Paint()..color = StealthColors.textPrimary);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
