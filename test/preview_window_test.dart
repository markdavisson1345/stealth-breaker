import 'package:flutter_test/flutter_test.dart';
import 'package:stealth_breaker/game/systems/preview_window.dart';

void main() {
  test('preview expires from wall-clock time even if updates were suspended',
      () {
    final start = DateTime.utc(2026, 9, 19, 12);
    final preview = PreviewWindow.start(start, const Duration(seconds: 3));
    expect(preview.isExpiredAt(start.add(const Duration(seconds: 2))), isFalse);
    // Represents returning after the app was backgrounded for ten seconds.
    expect(preview.isExpiredAt(start.add(const Duration(seconds: 10))), isTrue);
  });

  test('restart preview is blocked for 30 wall-clock seconds', () {
    final shown = DateTime.utc(2026, 9, 19, 12);
    expect(
        PreviewWindow.allowRestartPreview(
            now: shown.add(const Duration(seconds: 29)),
            lastPreviewShownAt: shown,
            cooldown: const Duration(seconds: 30)),
        isFalse);
    expect(
        PreviewWindow.allowRestartPreview(
            now: shown.add(const Duration(seconds: 30)),
            lastPreviewShownAt: shown,
            cooldown: const Duration(seconds: 30)),
        isTrue);
  });
}
