enum BrickKind { empty, normal, stealth }

enum BrickSpecialType { none, explosive, split, reinforced, bonus, extraShot }

class Brick {
  const Brick({
    required this.row,
    required this.column,
    required this.kind,
    required this.hitPoints,
    required this.maxHitPoints,
    this.specialType = BrickSpecialType.none,
  });

  final int row;
  final int column;
  final BrickKind kind;
  final int hitPoints;
  final int maxHitPoints;
  final BrickSpecialType specialType;

  bool get exists => kind != BrickKind.empty;
  bool get isStealth => kind == BrickKind.stealth;
  bool get isDestroyed => exists && hitPoints <= 0;

  Brick copyWith(
          {int? hitPoints, BrickKind? kind, BrickSpecialType? specialType}) =>
      Brick(
        row: row,
        column: column,
        kind: kind ?? this.kind,
        hitPoints: hitPoints ?? this.hitPoints,
        maxHitPoints: maxHitPoints,
        specialType: specialType ?? this.specialType,
      );

  factory Brick.empty(int row, int column) => Brick(
        row: row,
        column: column,
        kind: BrickKind.empty,
        hitPoints: 0,
        maxHitPoints: 0,
        specialType: BrickSpecialType.none,
      );
}
