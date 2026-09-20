import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../game/level/level_generator.dart';
import '../services/analytics_service.dart';
import '../widgets/game_button.dart';
import 'game_screen.dart';

class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key, required this.controller});
  final AppController controller;
  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final day = AppController.dateKey(now);
    final complete = widget.controller.progress.lastDailyCompleted == day;
    final best = widget.controller.progress.dailyBestScores[day];
    final generated = LevelGenerator.generate(
        level: 8, seed: LevelGenerator.seedForDate(now), daily: true);
    final nextReward = [3, 7, 14, 30]
        .where((v) => v > widget.controller.progress.dailyStreak)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Challenge')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.calendar_month_rounded,
                size: 72, color: Color(0xFF7C3AED)),
            const SizedBox(height: 18),
            Text(day, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
                'The same seeded challenge is generated for every player on this date.',
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Player powers are disabled for fair same-seed play.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.cyanAccent)),
            const SizedBox(height: 22),
            Text(complete ? 'Completed today' : 'Not completed yet',
                style: TextStyle(
                    color: complete ? Colors.greenAccent : Colors.orangeAccent,
                    fontWeight: FontWeight.bold)),
            if (best != null) Text('Best score: $best'),
            Text('${generated.brickCount} bricks • '
                '${generated.stealthCount} stealth • ${generated.shots} shots'),
            Text(
                'Current streak: ${widget.controller.progress.dailyStreak} day${widget.controller.progress.dailyStreak == 1 ? '' : 's'}'),
            if (nextReward != null)
              Text('Next streak reward: $nextReward days'),
            const SizedBox(height: 30),
            GameButton(
              label: complete ? 'Play Again' : 'Start Challenge',
              icon: Icons.play_arrow_rounded,
              onPressed: () async {
                widget.controller.analytics.dailyStart(day);
                await widget.controller.audio.playUiConfirm();
                if (!context.mounted) return;
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => GameScreen(
                              controller: widget.controller,
                              level: 8,
                              daily: true,
                              challengeDate: now,
                              seed: LevelGenerator.seedForDate(now),
                            )));
              },
            ),
          ]),
        ),
      ),
    );
  }
}
