# Architecture

## Boundary

Reusable infrastructure lives in `lib/services` and works with generic IDs,
events, profiles, settings, or inventory maps. Stealth Breaker rules—brick
types, scoring, board generation, achievement definitions, power definitions,
and Daily Challenge parameters—remain in `lib/game`, `lib/models`, and
`lib/config`.

Game identity and replaceable mappings are centralized in `lib/config`, while
the audio file map is private to `AudioplayersAudioService`.

## Player and persistence flow

`AppController` is the authoritative observable player state. Screens read it
and invoke transactions; they do not own copies of progression. A
`PlayerProfileRepository` boundary separates callers from the current
SharedPreferences implementation. Save schema v3 migrates older namespaced and
legacy keys and persists stats, achievements, Daily data, settings, and
inventory offline.

Future cloud save implements `CloudProgressService` and synchronizes through
the repository/controller boundary. `AuthenticationService` currently exposes
a guest identity; a later anonymous/cloud account can link the guest profile
without gameplay knowing the provider.

## Progression and achievements

Gameplay produces summarized reports and semantic `ProgressionEvent`s.
`AppController` atomically updates lifetime statistics, evaluates the
data-driven `AchievementCatalog`, grants each tier reward once, saves, and then
notifies all screens. Completed tier IDs are the idempotency record. Best-shot
families use maximum counters; lifetime families use cumulative counters.

## Daily Challenge

`LevelGenerator.seedForDate` creates the same board for a calendar date. The
information screen exposes counts only; geometry first appears during the
in-game preview. `DailyChallengeService.complete` is the single completion
transaction: it updates best score on every run, but completion count, streak,
date, and rewards only on the first successful completion for that date.
Date-only `YYYY-MM-DD` keys avoid timestamp/DST drift.

## Inventory

Unlocking a power permanently adds its ID and grants configured initial
charges. `InventoryService` performs generic grants and consumption. A charge
is reserved only when a normal level actually starts; Daily Challenges never
consume or permit powers. The generic grant API can later accept gameplay,
achievement, ad, or purchase reward sources and a cap.

## Audio, music, and haptics

UI/gameplay call semantic `AudioService` methods. The audioplayers adapter owns
predefined variations, volume, collision rate limits, looping, and track
deduplication. Menu, normal gameplay, and Daily Challenge tracks are distinct.
`HapticsService` gates native feedback through the persisted setting. The audio
lab is compile-time developer-only.

## Analytics and lifecycle

`AnalyticsService` receives low-frequency semantic events (session, screen,
level, shot summary, Daily, achievement, power, streak, settings). It is a
debug/no-op adapter today; Firebase Analytics and Crashlytics can be added as a
new adapter without changing gameplay. Flutter lifecycle callbacks keep preview
timing authoritative and prevent background time from extending memorization.

## Future services

`AdService`, `PurchaseService`, and `EntitlementService` are provider-neutral
interfaces. Production ads/IAP must implement consent, store verification,
restore purchases, entitlement reconciliation, and server-side validation.
None are active. Production authentication/cloud save still needs a provider,
account-link UI, merge/conflict policy, encryption, retries, and backend access
rules.
