import '../config/game_balance.dart';
import 'brick.dart';

class WorldDefinition {
  const WorldDefinition(
      {required this.number,
      required this.name,
      required this.densityMin,
      required this.densityMax,
      required this.stealthMultiplier,
      required this.hp2Rate,
      required this.hp3Rate,
      required this.shotBonus,
      required this.specialties});
  final int number;
  final String name;
  final double densityMin;
  final double densityMax;
  final double stealthMultiplier;
  final double hp2Rate;
  final double hp3Rate;
  final int shotBonus;
  final Set<BrickSpecialType> specialties;
}

abstract final class WorldCatalog {
  static const worlds = <WorldDefinition>[
    WorldDefinition(
        number: 1,
        name: 'Training Grounds',
        densityMin: .46,
        densityMax: .62,
        stealthMultiplier: .85,
        hp2Rate: .12,
        hp3Rate: 0,
        shotBonus: 3,
        specialties: {}),
    WorldDefinition(
        number: 2,
        name: 'Blackout',
        densityMin: .56,
        densityMax: .70,
        stealthMultiplier: 1.15,
        hp2Rate: .22,
        hp3Rate: .08,
        shotBonus: 2,
        specialties: {BrickSpecialType.bonus, BrickSpecialType.extraShot}),
    WorldDefinition(
        number: 3,
        name: 'Ricochet',
        densityMin: .62,
        densityMax: .76,
        stealthMultiplier: 1.35,
        hp2Rate: .28,
        hp3Rate: .15,
        shotBonus: 1,
        specialties: {
          BrickSpecialType.bonus,
          BrickSpecialType.extraShot,
          BrickSpecialType.explosive,
          BrickSpecialType.split
        }),
    WorldDefinition(
        number: 4,
        name: 'Overload',
        densityMin: .70,
        densityMax: .86,
        stealthMultiplier: 1.55,
        hp2Rate: .34,
        hp3Rate: .24,
        shotBonus: 0,
        specialties: {
          BrickSpecialType.bonus,
          BrickSpecialType.extraShot,
          BrickSpecialType.explosive,
          BrickSpecialType.split,
          BrickSpecialType.reinforced
        }),
  ];

  static WorldDefinition forLevel(int level) {
    final index =
        ((level - 1) ~/ GameBalance.levelsPerWorld).clamp(0, worlds.length - 1);
    return worlds[index];
  }

  static int levelInWorld(int level) =>
      ((level - 1) % GameBalance.levelsPerWorld) + 1;
  static bool isMilestone(int level) => level % GameBalance.levelsPerWorld == 0;
}
