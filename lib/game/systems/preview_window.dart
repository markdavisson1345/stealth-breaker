class PreviewWindow {
  PreviewWindow({required this.expiresAt});
  final DateTime expiresAt;

  factory PreviewWindow.start(DateTime now, Duration duration) =>
      PreviewWindow(expiresAt: now.add(duration));

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  static bool allowRestartPreview({
    required DateTime now,
    required DateTime? lastPreviewShownAt,
    required Duration cooldown,
  }) =>
      lastPreviewShownAt == null ||
      now.difference(lastPreviewShownAt) >= cooldown;
}
