import 'power.dart';

enum PowerChargeAwardSource {
  levelCompletion,
  mastery,
  dailyChallenge,
  achievement,
  streak,
  dailyObjective,
  weeklyObjective,
}

class PowerChargeAward {
  const PowerChargeAward({
    required this.power,
    required this.amount,
    required this.source,
  });

  final PowerId power;
  final int amount;
  final PowerChargeAwardSource source;

  String get label =>
      '+$amount ${power.displayName} Charge${amount == 1 ? '' : 's'}';
}
