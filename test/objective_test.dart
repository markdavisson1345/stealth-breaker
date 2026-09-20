import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/models/objective.dart';

void main() {
  test('daily objectives are deterministic and contain three distinct items',
      () {
    final first = ObjectiveCatalog.dailyFor('2026-09-19');
    final second = ObjectiveCatalog.dailyFor('2026-09-19');
    expect(first.map((e) => e.id), second.map((e) => e.id));
    expect(first, hasLength(3));
    expect(first.map((e) => e.id).toSet(), hasLength(3));
  });
}
