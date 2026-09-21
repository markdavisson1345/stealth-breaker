import 'dart:math';

class StarRating {
  const StarRating._();

  static int calculate({
    required bool levelCleared,
    required int originalStartingShots,
    required int shotsUsed,
  }) {
    if (!levelCleared || originalStartingShots <= 0) return 0;

    final originalShotsRemaining =
        max(0, originalStartingShots - max(0, shotsUsed));
    final remainingPercentPoints = originalShotsRemaining * 100;
    final allowancePercentPoints = originalStartingShots;

    if (remainingPercentPoints > allowancePercentPoints * 35) return 3;
    if (remainingPercentPoints >= allowancePercentPoints * 20) return 2;
    return 1;
  }
}
