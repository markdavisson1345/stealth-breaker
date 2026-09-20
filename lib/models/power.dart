enum PowerId { scannerPulse, trajectoryPlus, powerShot, secondChance }

extension PowerDefinition on PowerId {
  String get storageId => name;
  String get displayName => switch (this) {
        PowerId.scannerPulse => 'Scanner Pulse',
        PowerId.trajectoryPlus => 'Trajectory+',
        PowerId.powerShot => 'Power Shot',
        PowerId.secondChance => 'Second Chance',
      };

  String get description => switch (this) {
        PowerId.scannerPulse =>
          'Briefly reveal every hidden stealth brick once per level.',
        PowerId.trajectoryPlus =>
          'Show a longer trajectory guide with more predicted bounces.',
        PowerId.powerShot =>
          'The first brick struck by your next shot takes 2 damage.',
        PowerId.secondChance => 'Manually restore one shot after running out.',
      };
}
