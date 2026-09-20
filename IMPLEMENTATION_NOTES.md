# Implementation notes

## Prototype audit

The supplied files contained the visual/menu concept but were not a complete Flutter project. The original state used loose maps, a fixed ball coordinate, a fixed upward launch, an empty periodic timer, nonfunctional trajectory/collision code, hard-coded Daily and achievement data, nonpersistent settings, duplicate menus, syntax errors, and no Android host or package manifest.

The implementation replaces those systems rather than layering more timers and state patches on them.

## Physics boundary

All positions are local to the Flame gameplay viewport beneath the Flutter HUD. Brick geometry, trajectory, ball reset, and wall collision therefore use the same coordinate space. The brick field caps each brick at 52 logical pixels wide and centers unused width as margin.

## Preview security

The preview owns an absolute expiration timestamp. Flame checks it during updates, and the Flutter lifecycle observer checks it immediately when Android resumes. `requestPause`, `beginAim`, and `releaseAim` all reject invalid phases.

## Remaining release work

- Run the documented Flutter/Android validation on a machine with the SDKs installed.
- Play-balance brick density, shot counts, scores, and ball speed using real device sessions.
- Add licensed audio assets before enabling sound/music controls.
- Replace test signing with a protected upload key.
- Add production provider implementations only when ads/billing/analytics are selected.
- Add app icons, screenshots, privacy policy, store metadata, age/content ratings, and iOS host configuration during store-release work.
