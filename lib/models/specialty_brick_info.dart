import 'brick.dart';

class SpecialtyBrickInfo {
  const SpecialtyBrickInfo({
    required this.type,
    required this.name,
    required this.symbol,
    required this.description,
    required this.stealthNote,
    required this.sampleHitPoints,
  });

  final BrickSpecialType type;
  final String name;
  final String symbol;
  final String description;
  final String stealthNote;
  final int sampleHitPoints;
}

abstract final class SpecialtyBrickCatalog {
  static const all = <SpecialtyBrickInfo>[
    SpecialtyBrickInfo(
      type: BrickSpecialType.explosive,
      name: 'Explosive',
      symbol: '✹',
      description:
          'When destroyed, deals 1 damage to every adjacent brick. Destroyed explosives can chain.',
      stealthNote: 'Can be stealth in Overload.',
      sampleHitPoints: 1,
    ),
    SpecialtyBrickInfo(
      type: BrickSpecialType.split,
      name: 'Split',
      symbol: '⑂',
      description:
          'When destroyed, launches an extra angled ball, up to 3 active balls.',
      stealthNote: 'Never appears as a stealth brick.',
      sampleHitPoints: 1,
    ),
    SpecialtyBrickInfo(
      type: BrickSpecialType.reinforced,
      name: 'Reinforced',
      symbol: '◆',
      description: 'Has 4 hit points and must be hit repeatedly to break.',
      stealthNote: 'Can be stealth in Overload.',
      sampleHitPoints: 4,
    ),
    SpecialtyBrickInfo(
      type: BrickSpecialType.bonus,
      name: 'Bonus',
      symbol: '★',
      description: 'Awards 500 bonus points when destroyed.',
      stealthNote: 'Can appear as a stealth brick.',
      sampleHitPoints: 1,
    ),
    SpecialtyBrickInfo(
      type: BrickSpecialType.extraShot,
      name: 'Extra Shot',
      symbol: '+',
      description: 'Adds 1 shot when destroyed.',
      stealthNote: 'Never appears as a stealth brick.',
      sampleHitPoints: 1,
    ),
  ];

  static SpecialtyBrickInfo byType(BrickSpecialType type) =>
      all.firstWhere((value) => value.type == type);
}
