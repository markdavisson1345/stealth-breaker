import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import '../models/game_settings.dart';

enum MusicTrack { menu, gameplay, dailyChallenge }

abstract interface class AudioService {
  Future<void> initialize(GameSettings settings);
  Future<void> applySettings(GameSettings settings);
  Future<void> handleLifecycleState(AppLifecycleState state);
  Future<void> playUiTap();
  Future<void> playUiBack();
  Future<void> playUiConfirm();
  Future<void> playLevelStart();
  Future<void> playPreviewScan();
  Future<void> playStealthDisappear();
  Future<void> playBallLaunch();
  Future<void> playWallBounce();
  Future<void> playBrickHit();
  Future<void> playBrickBreak();
  Future<void> playStealthHit();
  Future<void> playLevelComplete();
  Future<void> playLevelFailed();
  Future<void> playAchievementUnlock();
  Future<void> playApReward();
  Future<void> playMusic(MusicTrack track);
  Future<void> stopMusic();
  Future<void> dispose();
}

class AudioplayersAudioService implements AudioService {
  final _music = AudioPlayer();
  final _pool = List.generate(8, (_) => AudioPlayer());
  final _random = Random();
  var _poolIndex = 0;
  var _settings = const GameSettings();
  MusicTrack? _currentMusic;
  MusicTrack? _loadedMusic;
  bool _active = true;
  bool _pausedForLifecycle = false;
  final Map<String, DateTime> _lastPlayed = {};

  static const _musicFiles = {
    MusicTrack.menu: 'audio/music/menu_loop.ogg',
    MusicTrack.gameplay: 'audio/music/gameplay_loop.ogg',
    MusicTrack.dailyChallenge: 'audio/music/daily_challenge_loop.ogg',
  };

  static const _preload = [
    'audio/sfx/gameplay/ball_launch.wav',
    'audio/sfx/gameplay/wall_bounce_01.wav',
    'audio/sfx/gameplay/wall_bounce_02.wav',
    'audio/sfx/gameplay/brick_hit_01.wav',
    'audio/sfx/gameplay/brick_hit_02.wav',
    'audio/sfx/gameplay/brick_hit_03.wav',
    'audio/sfx/gameplay/brick_break.wav',
    'audio/sfx/gameplay/stealth_hit.wav',
  ];

  @override
  Future<void> initialize(GameSettings settings) async {
    _settings = settings;
    await _music.setReleaseMode(ReleaseMode.loop);
    for (var i = 0; i < _preload.length; i++) {
      try {
        await _pool[i].setSource(AssetSource(_preload[i]));
      } catch (_) {
        // Audio may be unavailable or blocked until interaction in a browser.
      }
    }
  }

  @override
  Future<void> applySettings(GameSettings settings) async {
    _settings = settings;
    await _music.setVolume(settings.music ? settings.musicVolume : 0);
    if (!settings.music || settings.musicVolume <= 0) {
      await _music.stop();
      _loadedMusic = null;
      _pausedForLifecycle = false;
    } else if (_active && _currentMusic != null) {
      await playMusic(_currentMusic!);
    }
  }

  @override
  Future<void> handleLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      _active = true;
      if (!_settings.music || _settings.musicVolume <= 0) return;
      if (_pausedForLifecycle && _loadedMusic == _currentMusic) {
        try {
          await _music.resume();
          _pausedForLifecycle = false;
        } catch (_) {
          if (_currentMusic != null) await playMusic(_currentMusic!);
        }
      } else if (_currentMusic != null && _loadedMusic != _currentMusic) {
        await playMusic(_currentMusic!);
      }
      return;
    }
    _active = false;
    if (_loadedMusic != null && !_pausedForLifecycle) {
      try {
        await _music.pause();
        _pausedForLifecycle = true;
      } catch (_) {
        await _music.stop();
        _loadedMusic = null;
        _pausedForLifecycle = false;
      }
    }
  }

  Future<void> _sfx(String file,
      {double gain = 1, String? limiter, int minimumMs = 0}) async {
    if (!_active || !_settings.soundEffects || _settings.sfxVolume <= 0) {
      return;
    }
    if (limiter != null) {
      final now = DateTime.now();
      final last = _lastPlayed[limiter];
      if (last != null && now.difference(last).inMilliseconds < minimumMs) {
        return;
      }
      _lastPlayed[limiter] = now;
    }
    try {
      final player = _pool[_poolIndex++ % _pool.length];
      await player.setVolume((_settings.sfxVolume * gain).clamp(0, 1));
      await player.play(AssetSource(file));
    } catch (_) {
      // Browser autoplay and unavailable audio devices must not break gameplay.
    }
  }

  @override
  Future<void> playUiTap() => _sfx('audio/sfx/ui/ui_tap.wav');
  @override
  Future<void> playUiBack() => _sfx('audio/sfx/ui/ui_back.wav');
  @override
  Future<void> playUiConfirm() => _sfx('audio/sfx/ui/ui_confirm.wav');
  @override
  Future<void> playLevelStart() => _sfx('audio/sfx/gameplay/level_start.wav');
  @override
  Future<void> playPreviewScan() => _sfx('audio/sfx/gameplay/preview_scan.wav');
  @override
  Future<void> playStealthDisappear() =>
      _sfx('audio/sfx/gameplay/stealth_disappear.wav');
  @override
  Future<void> playBallLaunch() => _sfx('audio/sfx/gameplay/ball_launch.wav');
  @override
  Future<void> playWallBounce() =>
      _sfx('audio/sfx/gameplay/wall_bounce_0${1 + _random.nextInt(2)}.wav',
          gain: .16, limiter: 'wall', minimumMs: 42);
  @override
  Future<void> playBrickHit() =>
      _sfx('audio/sfx/gameplay/brick_hit_0${1 + _random.nextInt(3)}.wav',
          gain: .28, limiter: 'brick', minimumMs: 32);
  @override
  Future<void> playBrickBreak() =>
      _sfx('audio/sfx/gameplay/brick_break.wav', gain: .75);
  @override
  Future<void> playStealthHit() => _sfx('audio/sfx/gameplay/stealth_hit.wav');
  @override
  Future<void> playLevelComplete() =>
      _sfx('audio/sfx/rewards/level_complete.wav');
  @override
  Future<void> playLevelFailed() => _sfx('audio/sfx/rewards/level_failed.wav');
  @override
  Future<void> playAchievementUnlock() =>
      _sfx('audio/sfx/rewards/achievement_unlock.wav');
  @override
  Future<void> playApReward() => _sfx('audio/sfx/rewards/ap_reward.wav');

  @override
  Future<void> playMusic(MusicTrack track) async {
    _currentMusic = track;
    if (!_active || !_settings.music || _settings.musicVolume <= 0) {
      return;
    }
    if (_loadedMusic == track) {
      if (_pausedForLifecycle) {
        await _music.resume();
        _pausedForLifecycle = false;
      }
      return;
    }
    try {
      await _music.stop();
      await _music.setVolume(_settings.musicVolume);
      await _music.play(AssetSource(_musicFiles[track]!));
      _loadedMusic = track;
      _pausedForLifecycle = false;
    } catch (_) {
      _loadedMusic = null;
    }
  }

  @override
  Future<void> stopMusic() async {
    await _music.stop();
    _currentMusic = null;
    _loadedMusic = null;
    _pausedForLifecycle = false;
  }

  @override
  Future<void> dispose() async {
    await _music.dispose();
    for (final player in _pool) {
      await player.dispose();
    }
  }
}

class NoopAudioService implements AudioService {
  const NoopAudioService();
  @override
  Future<void> initialize(GameSettings settings) async {}
  @override
  Future<void> applySettings(GameSettings settings) async {}
  @override
  Future<void> handleLifecycleState(AppLifecycleState state) async {}
  @override
  Future<void> playUiTap() async {}
  @override
  Future<void> playUiBack() async {}
  @override
  Future<void> playUiConfirm() async {}
  @override
  Future<void> playLevelStart() async {}
  @override
  Future<void> playPreviewScan() async {}
  @override
  Future<void> playStealthDisappear() async {}
  @override
  Future<void> playBallLaunch() async {}
  @override
  Future<void> playWallBounce() async {}
  @override
  Future<void> playBrickHit() async {}
  @override
  Future<void> playBrickBreak() async {}
  @override
  Future<void> playStealthHit() async {}
  @override
  Future<void> playLevelComplete() async {}
  @override
  Future<void> playLevelFailed() async {}
  @override
  Future<void> playAchievementUnlock() async {}
  @override
  Future<void> playApReward() async {}
  @override
  Future<void> playMusic(MusicTrack track) async {}
  @override
  Future<void> stopMusic() async {}
  @override
  Future<void> dispose() async {}
}
