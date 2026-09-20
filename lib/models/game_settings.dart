enum EffectsQuality { low, medium, high }

class GameSettings {
  const GameSettings({
    this.soundEffects = true,
    this.music = true,
    this.haptics = true,
    this.sfxVolume = .8,
    this.musicVolume = .35,
    this.trajectoryPreview = true,
    this.showCombo = true,
    this.effectsQuality = EffectsQuality.medium,
  });

  final bool soundEffects;
  final bool music;
  final bool haptics;
  final double sfxVolume;
  final double musicVolume;
  final bool trajectoryPreview;
  final bool showCombo;
  final EffectsQuality effectsQuality;

  GameSettings copyWith(
          {bool? soundEffects,
          bool? music,
          bool? haptics,
          double? sfxVolume,
          double? musicVolume,
          bool? trajectoryPreview,
          bool? showCombo,
          EffectsQuality? effectsQuality}) =>
      GameSettings(
        soundEffects: soundEffects ?? this.soundEffects,
        music: music ?? this.music,
        haptics: haptics ?? this.haptics,
        sfxVolume: (sfxVolume ?? this.sfxVolume).clamp(0, 1),
        musicVolume: (musicVolume ?? this.musicVolume).clamp(0, 1),
        trajectoryPreview: trajectoryPreview ?? this.trajectoryPreview,
        showCombo: showCombo ?? this.showCombo,
        effectsQuality: effectsQuality ?? this.effectsQuality,
      );

  Map<String, Object> toJson() => {
        'soundEffects': soundEffects,
        'music': music,
        'haptics': haptics,
        'sfxVolume': sfxVolume,
        'musicVolume': musicVolume,
        'trajectoryPreview': trajectoryPreview,
        'showCombo': showCombo,
        'effectsQuality': effectsQuality.name,
      };

  factory GameSettings.fromJson(Map<String, dynamic> json) => GameSettings(
        soundEffects: json['soundEffects'] as bool? ?? true,
        music: json['music'] as bool? ?? true,
        haptics: json['haptics'] as bool? ?? true,
        sfxVolume: ((json['sfxVolume'] as num?)?.toDouble() ?? .8).clamp(0, 1),
        musicVolume:
            ((json['musicVolume'] as num?)?.toDouble() ?? .35).clamp(0, 1),
        trajectoryPreview: json['trajectoryPreview'] as bool? ?? true,
        showCombo: json['showCombo'] as bool? ?? true,
        effectsQuality: _quality(json['effectsQuality']),
      );

  static EffectsQuality _quality(Object? value) {
    for (final quality in EffectsQuality.values) {
      if (quality.name == value) return quality;
    }
    return EffectsQuality.medium;
  }
}
