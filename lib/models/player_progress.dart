import 'objective.dart';
import 'power.dart';

class PlayerProgress {
  const PlayerProgress({
    this.saveVersion = 4,
    this.highestLevel = 1,
    this.highScore = 0,
    this.totalScore = 0,
    this.totalBricksDestroyed = 0,
    this.stealthBricksDestroyed = 0,
    this.levelsCompleted = 0,
    this.dailyChallengesCompleted = 0,
    this.dailyStreak = 0,
    this.longestDailyStreak = 0,
    this.lastDailyCompleted,
    this.dailyBestScores = const {},
    this.achievementCounters = const {},
    this.completedAchievementTiers = const {},
    this.achievementPoints = 0,
    this.unlockedPowers = const {},
    this.powerCharges = const {},
    this.equippedPower,
    this.levelStars = const {},
    this.wallBounceHits = 0,
    this.efficientLevels = 0,
    this.highestOneShot = 0,
    this.fewestShotsUsed = 0,
    this.totalStars = 0,
    this.specialtyBricksDestroyed = 0,
    this.streakSaves = 0,
    this.claimedStreakRewards = const {},
    this.dailyObjectives,
    this.weeklyObjectives,
    this.seenSpecialtyTutorials = const {},
    this.tutorialComplete = false,
    this.futureSoftCurrency = 0,
  });

  final int saveVersion;
  final int highestLevel;
  final int highScore;
  final int totalScore;
  final int totalBricksDestroyed;
  final int stealthBricksDestroyed;
  final int levelsCompleted;
  final int dailyChallengesCompleted;
  final int dailyStreak;
  final int longestDailyStreak;
  final String? lastDailyCompleted;
  final Map<String, int> dailyBestScores;
  final Map<String, int> achievementCounters;
  final Set<String> completedAchievementTiers;
  final int achievementPoints;
  final Set<String> unlockedPowers;
  final Map<String, int> powerCharges;
  final String? equippedPower;
  final Map<String, int> levelStars;
  final int wallBounceHits;
  final int efficientLevels;
  final int highestOneShot;
  final int fewestShotsUsed;
  final int totalStars;
  final int specialtyBricksDestroyed;
  final int streakSaves;
  final Set<int> claimedStreakRewards;
  final ObjectiveSetState? dailyObjectives;
  final ObjectiveSetState? weeklyObjectives;
  final Set<String> seenSpecialtyTutorials;
  final bool tutorialComplete;
  final int futureSoftCurrency;

  bool isPowerUnlocked(PowerId id) => unlockedPowers.contains(id.storageId);

  PlayerProgress copyWith({
    int? saveVersion,
    int? highestLevel,
    int? highScore,
    int? totalScore,
    int? totalBricksDestroyed,
    int? stealthBricksDestroyed,
    int? levelsCompleted,
    int? dailyChallengesCompleted,
    int? dailyStreak,
    int? longestDailyStreak,
    String? lastDailyCompleted,
    bool clearLastDailyCompleted = false,
    Map<String, int>? dailyBestScores,
    Map<String, int>? achievementCounters,
    Set<String>? completedAchievementTiers,
    int? achievementPoints,
    Set<String>? unlockedPowers,
    Map<String, int>? powerCharges,
    String? equippedPower,
    bool clearEquippedPower = false,
    Map<String, int>? levelStars,
    int? wallBounceHits,
    int? efficientLevels,
    int? highestOneShot,
    int? fewestShotsUsed,
    int? totalStars,
    int? specialtyBricksDestroyed,
    int? streakSaves,
    Set<int>? claimedStreakRewards,
    ObjectiveSetState? dailyObjectives,
    ObjectiveSetState? weeklyObjectives,
    Set<String>? seenSpecialtyTutorials,
    bool? tutorialComplete,
    int? futureSoftCurrency,
  }) =>
      PlayerProgress(
        saveVersion: saveVersion ?? this.saveVersion,
        highestLevel: highestLevel ?? this.highestLevel,
        highScore: highScore ?? this.highScore,
        totalScore: totalScore ?? this.totalScore,
        totalBricksDestroyed: totalBricksDestroyed ?? this.totalBricksDestroyed,
        stealthBricksDestroyed:
            stealthBricksDestroyed ?? this.stealthBricksDestroyed,
        levelsCompleted: levelsCompleted ?? this.levelsCompleted,
        dailyChallengesCompleted:
            dailyChallengesCompleted ?? this.dailyChallengesCompleted,
        dailyStreak: dailyStreak ?? this.dailyStreak,
        longestDailyStreak: longestDailyStreak ?? this.longestDailyStreak,
        lastDailyCompleted: clearLastDailyCompleted
            ? null
            : lastDailyCompleted ?? this.lastDailyCompleted,
        dailyBestScores: dailyBestScores ?? this.dailyBestScores,
        achievementCounters: achievementCounters ?? this.achievementCounters,
        completedAchievementTiers:
            completedAchievementTiers ?? this.completedAchievementTiers,
        achievementPoints: achievementPoints ?? this.achievementPoints,
        unlockedPowers: unlockedPowers ?? this.unlockedPowers,
        powerCharges: powerCharges ?? this.powerCharges,
        equippedPower:
            clearEquippedPower ? null : equippedPower ?? this.equippedPower,
        levelStars: levelStars ?? this.levelStars,
        wallBounceHits: wallBounceHits ?? this.wallBounceHits,
        efficientLevels: efficientLevels ?? this.efficientLevels,
        highestOneShot: highestOneShot ?? this.highestOneShot,
        fewestShotsUsed: fewestShotsUsed ?? this.fewestShotsUsed,
        totalStars: totalStars ?? this.totalStars,
        specialtyBricksDestroyed:
            specialtyBricksDestroyed ?? this.specialtyBricksDestroyed,
        streakSaves: streakSaves ?? this.streakSaves,
        claimedStreakRewards: claimedStreakRewards ?? this.claimedStreakRewards,
        dailyObjectives: dailyObjectives ?? this.dailyObjectives,
        weeklyObjectives: weeklyObjectives ?? this.weeklyObjectives,
        seenSpecialtyTutorials:
            seenSpecialtyTutorials ?? this.seenSpecialtyTutorials,
        tutorialComplete: tutorialComplete ?? this.tutorialComplete,
        futureSoftCurrency: futureSoftCurrency ?? this.futureSoftCurrency,
      );

  Map<String, Object?> toJson() => {
        'saveVersion': 4,
        'highestLevel': highestLevel,
        'highScore': highScore,
        'totalScore': totalScore,
        'totalBricksDestroyed': totalBricksDestroyed,
        'stealthBricksDestroyed': stealthBricksDestroyed,
        'levelsCompleted': levelsCompleted,
        'dailyChallengesCompleted': dailyChallengesCompleted,
        'dailyStreak': dailyStreak,
        'longestDailyStreak': longestDailyStreak,
        'lastDailyCompleted': lastDailyCompleted,
        'dailyBestScores': dailyBestScores,
        'achievementCounters': achievementCounters,
        'completedAchievementTiers': completedAchievementTiers.toList(),
        'achievementPoints': achievementPoints,
        'unlockedPowers': unlockedPowers.toList(),
        'powerCharges': powerCharges,
        'equippedPower': equippedPower,
        'levelStars': levelStars,
        'wallBounceHits': wallBounceHits,
        'efficientLevels': efficientLevels,
        'highestOneShot': highestOneShot,
        'fewestShotsUsed': fewestShotsUsed,
        'totalStars': totalStars,
        'specialtyBricksDestroyed': specialtyBricksDestroyed,
        'streakSaves': streakSaves,
        'claimedStreakRewards': claimedStreakRewards.toList(),
        'dailyObjectives': dailyObjectives?.toJson(),
        'weeklyObjectives': weeklyObjectives?.toJson(),
        'seenSpecialtyTutorials': seenSpecialtyTutorials.toList(),
        'tutorialComplete': tutorialComplete,
        'futureSoftCurrency': futureSoftCurrency,
      };

  factory PlayerProgress.fromJson(Map<String, dynamic> json) {
    final sourceVersion = _int(json['saveVersion'], 1);
    final legacyProgress = _intMap(json['achievementProgress']);
    final counters = _intMap(json['achievementCounters']);
    if (counters.isEmpty && legacyProgress.isNotEmpty) {
      counters['stealthHunter'] =
          legacyProgress['stealth_50'] ?? legacyProgress['stealth_10'] ?? 0;
      counters['brickBarrage'] = legacyProgress['combo_5'] ?? 0;
      counters['levelMaster'] = legacyProgress['first_level'] ?? 0;
    }
    return PlayerProgress(
      saveVersion: sourceVersion,
      highestLevel: _int(json['highestLevel'], 1),
      highScore: _int(json['highScore']),
      totalScore: _int(json['totalScore']),
      totalBricksDestroyed: _int(json['totalBricksDestroyed']),
      stealthBricksDestroyed: _int(json['stealthBricksDestroyed']),
      levelsCompleted: _int(json['levelsCompleted']),
      dailyChallengesCompleted: _int(json['dailyChallengesCompleted']),
      dailyStreak: _int(json['dailyStreak']),
      longestDailyStreak: _int(json['longestDailyStreak']),
      lastDailyCompleted: json['lastDailyCompleted'] as String?,
      dailyBestScores: _intMap(json['dailyBestScores']),
      achievementCounters: counters,
      completedAchievementTiers: _stringSet(json['completedAchievementTiers']),
      achievementPoints: _int(json['achievementPoints']),
      unlockedPowers: _stringSet(json['unlockedPowers']),
      powerCharges: _intMap(json['powerCharges']),
      equippedPower: json['equippedPower'] as String?,
      levelStars: _intMap(json['levelStars']),
      wallBounceHits: _int(json['wallBounceHits']),
      efficientLevels: _int(json['efficientLevels']),
      highestOneShot: _int(json['highestOneShot']),
      fewestShotsUsed: _int(json['fewestShotsUsed']),
      totalStars: _int(json['totalStars']),
      specialtyBricksDestroyed: _int(json['specialtyBricksDestroyed']),
      streakSaves: _int(json['streakSaves']),
      claimedStreakRewards: _intSet(json['claimedStreakRewards']),
      dailyObjectives: _objectiveSet(json['dailyObjectives']),
      weeklyObjectives: _objectiveSet(json['weeklyObjectives']),
      seenSpecialtyTutorials: _stringSet(json['seenSpecialtyTutorials']),
      tutorialComplete: json['tutorialComplete'] as bool? ?? false,
      futureSoftCurrency: _int(json['futureSoftCurrency']),
    );
  }

  static int _int(Object? value, [int fallback = 0]) =>
      value is num ? value.toInt() : fallback;
  static Map<String, int> _intMap(Object? value) =>
      value is Map ? value.map((k, v) => MapEntry(k.toString(), _int(v))) : {};
  static Set<String> _stringSet(Object? value) =>
      ((value as List?) ?? const []).map((e) => e.toString()).toSet();
  static Set<int> _intSet(Object? value) =>
      ((value as List?) ?? const []).map((e) => _int(e)).toSet();
  static ObjectiveSetState? _objectiveSet(Object? value) => value is Map
      ? ObjectiveSetState.fromJson(Map<String, dynamic>.from(value))
      : null;
}
