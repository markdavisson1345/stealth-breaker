enum ObjectivePeriod { daily, weekly }

enum ObjectiveCategory { destruction, completion, performance, challenge, power }

enum ObjectiveType {
  destroyBricks,
  destroyStealthBricks,
  destroySpecialtyBricks,
  completeLevels,
  earnStars,
  bestShot,
  completeDailyChallenges,
  usePowerUps,
  efficientLevels,
  completeLevelsWithoutPower,
  completeDailyObjectives,
  threeStarCompletions,
  highValueShots,
  earnAchievementPoints,
}

class ObjectiveReward {
  const ObjectiveReward({required this.ap, this.powerCharges = 0});

  final int ap;
  final int powerCharges;

  Map<String, Object> toJson() => {
        'ap': ap,
        'powerCharges': powerCharges,
      };

  factory ObjectiveReward.fromJson(Map<String, dynamic> json) =>
      ObjectiveReward(
        ap: (json['ap'] as num?)?.toInt() ?? 0,
        powerCharges: (json['powerCharges'] as num?)?.toInt() ?? 0,
      );
}

class ObjectiveState {
  const ObjectiveState({
    required this.id,
    required this.type,
    required this.category,
    required this.description,
    required this.target,
    required this.reward,
    this.qualifier = 0,
    this.progress = 0,
    this.completed = false,
    this.rewardGranted = false,
    this.completedAtKey,
  });

  final String id;
  final ObjectiveType type;
  final ObjectiveCategory category;
  final String description;
  final int target;
  final int qualifier;
  final int progress;
  final ObjectiveReward reward;
  final bool completed;
  final bool rewardGranted;
  final String? completedAtKey;

  ObjectiveState copyWith({
    int? progress,
    bool? completed,
    bool? rewardGranted,
    String? completedAtKey,
  }) =>
      ObjectiveState(
        id: id,
        type: type,
        category: category,
        description: description,
        target: target,
        qualifier: qualifier,
        progress: progress ?? this.progress,
        reward: reward,
        completed: completed ?? this.completed,
        rewardGranted: rewardGranted ?? this.rewardGranted,
        completedAtKey: completedAtKey ?? this.completedAtKey,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'category': category.name,
        'description': description,
        'target': target,
        'qualifier': qualifier,
        'progress': progress,
        'reward': reward.toJson(),
        'completed': completed,
        'rewardGranted': rewardGranted,
        'completedAtKey': completedAtKey,
      };

  factory ObjectiveState.fromJson(Map<String, dynamic> json) => ObjectiveState(
        id: json['id'] as String? ?? '',
        type: ObjectiveType.values.firstWhere(
          (value) => value.name == json['type'],
          orElse: () => ObjectiveType.destroyBricks,
        ),
        category: ObjectiveCategory.values.firstWhere(
          (value) => value.name == json['category'],
          orElse: () => ObjectiveCategory.destruction,
        ),
        description: json['description'] as String? ?? 'Destroy bricks',
        target: (json['target'] as num?)?.toInt() ?? 1,
        qualifier: (json['qualifier'] as num?)?.toInt() ?? 0,
        progress: (json['progress'] as num?)?.toInt() ?? 0,
        reward: ObjectiveReward.fromJson(
          Map<String, dynamic>.from(json['reward'] as Map? ?? const {}),
        ),
        completed: json['completed'] as bool? ?? false,
        rewardGranted: json['rewardGranted'] as bool? ?? false,
        completedAtKey: json['completedAtKey'] as String?,
      );
}

class ObjectiveSetState {
  const ObjectiveSetState({
    required this.period,
    required this.key,
    required this.objectives,
  });

  final ObjectivePeriod period;
  final String key;
  final List<ObjectiveState> objectives;

  ObjectiveSetState copyWith({List<ObjectiveState>? objectives}) =>
      ObjectiveSetState(
        period: period,
        key: key,
        objectives: objectives ?? this.objectives,
      );

  Map<String, Object> toJson() => {
        'period': period.name,
        'key': key,
        'objectives': objectives.map((value) => value.toJson()).toList(),
      };

  factory ObjectiveSetState.fromJson(Map<String, dynamic> json) =>
      ObjectiveSetState(
        period: ObjectivePeriod.values.firstWhere(
          (value) => value.name == json['period'],
          orElse: () => ObjectivePeriod.daily,
        ),
        key: json['key'] as String? ?? '',
        objectives: ((json['objectives'] as List?) ?? const [])
            .whereType<Map>()
            .map((value) => ObjectiveState.fromJson(
                Map<String, dynamic>.from(value)))
            .toList(growable: false),
      );
}

class ObjectiveCompletionNotice {
  const ObjectiveCompletionNotice({
    required this.period,
    required this.objective,
    this.chargeLabel,
  });

  final ObjectivePeriod period;
  final ObjectiveState objective;
  final String? chargeLabel;

  String get title =>
      '${period == ObjectivePeriod.daily ? 'Daily' : 'Weekly'} objective complete';
}
