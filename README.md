# Stealth Breaker

Stealth Breaker is an offline-first Flutter/Flame arcade game built around a
memory brick-breaking loop: **See → Remember → Aim → Break**. The board is
visible during a short preview, stealth bricks disappear, and the player uses
remembered positions and ricochets to clear the level.

## Status

`v0.1.0-alpha` is an Android/web playtest build. It includes procedural normal
levels, a deterministic Daily Challenge, tiered achievements, local save-data
migration, consumable power-up charges, semantic analytics hooks, persisted
audio/music/haptic settings, and the supplied first-pass audio package. Ads,
billing, production authentication, cloud save, and Firebase are intentionally
inactive.

## Run and test

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Build Android and web:

```bash
flutter build apk --release
flutter build web --release --no-tree-shake-icons
```

Android output: `build/app/outputs/flutter-apk/app-release.apk`  
Web output: `build/web/`

## Audio

SFX and the three music loops live under `assets/audio/`. Gameplay calls the
semantic `AudioService` API; asset filenames are isolated in its implementation
so individual sounds can be replaced without changing game logic.

## Structure

- `lib/config/` — identity, balance, thresholds, and game-specific definitions
- `lib/game/` — Flame simulation, physics, rendering, and level generation
- `lib/models/` — persisted player/settings and gameplay data
- `lib/services/` — reusable persistence, audio, haptics, inventory,
  achievements, event, analytics, identity, and monetization interfaces
- `lib/screens/` — Stealth Breaker UI and navigation
- `test/` — automated regression tests
- `tool/regression_check.dart` — deterministic portable regression harness

See `ARCHITECTURE.md` for state and integration flows.
