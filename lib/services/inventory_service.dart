class InventoryChange {
  const InventoryChange({
    required this.inventory,
    required this.changed,
    required this.remaining,
  });

  final Map<String, int> inventory;
  final bool changed;
  final int remaining;
}

class InventoryService {
  const InventoryService();

  InventoryChange grant(
    Map<String, int> current,
    String itemId,
    int amount, {
    int? cap,
  }) {
    final inventory = Map<String, int>.from(current);
    final previous = inventory[itemId] ?? 0;
    final next = (previous + amount).clamp(0, cap ?? 0x7fffffff);
    inventory[itemId] = next;
    return InventoryChange(
      inventory: inventory,
      changed: next != previous,
      remaining: next,
    );
  }

  InventoryChange consume(
    Map<String, int> current,
    String itemId, {
    int amount = 1,
  }) {
    final previous = current[itemId] ?? 0;
    if (amount <= 0 || previous < amount) {
      return InventoryChange(
        inventory: Map.unmodifiable(current),
        changed: false,
        remaining: previous,
      );
    }
    final inventory = Map<String, int>.from(current)
      ..[itemId] = previous - amount;
    return InventoryChange(
      inventory: inventory,
      changed: true,
      remaining: previous - amount,
    );
  }
}
