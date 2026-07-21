# OSRS Stats — Wise Old Man iOS app

A small SwiftUI iPhone/iPad app that looks up an Old School RuneScape player and
shows their **current stats**, **XP gained over a day** (or week/month/year), and
**boss kill counts & activity scores** — all from the
[Wise Old Man](https://wiseoldman.net) API, so you don't have to open the website.

## Features

- Search any RuneScape name.
- **Summary card:** combat level, total level, total XP, EHP, EHB, and XP gained
  in the selected period.
- **Skills table:** level, experience, rank and gained XP per skill.
- **Bosses:** kill counts, rank and kills gained.
- **Activities & clues:** scores, rank and gained.
- Period switch (Day / Week / Month / Year) for all gains.
- **Update** button to track a new player or pull a fresh snapshot from the
  official hiscores.

## Requirements

- Xcode 16 or newer
- iOS 17.0+ (iPhone or iPad)

## Running

1. Open `WiseOldManStats.xcodeproj` in Xcode.
2. Select an iPhone simulator (or your device) and press **Run** (⌘R).
3. Type a RuneScape name and tap **Look up**. If the player isn't tracked yet,
   tap **Update** to add them.

> No account, API key or signing setup is required to run in the simulator.
> On a physical device, set your own Team under *Signing & Capabilities*.

## How it works

The app talks to the Wise Old Man v2 REST API
([docs](https://docs.wiseoldman.net/)):

| What | Endpoint |
|------|----------|
| Player details & latest snapshot | `GET /players/{username}` |
| XP / KC gained over a period | `GET /players/{username}/gained?period=day` |
| Track / refresh a player | `POST /players/{username}` |

Networking lives in [`WOMService.swift`](WiseOldManStats/WOMService.swift),
the response models in [`Models.swift`](WiseOldManStats/Models.swift), and the
UI in [`ContentView.swift`](WiseOldManStats/ContentView.swift) /
[`Cards.swift`](WiseOldManStats/Cards.swift).

## Project layout

```
WiseOldManStats.xcodeproj        Xcode project
WiseOldManStats/
  WiseOldManStatsApp.swift        App entry point
  ContentView.swift               Search UI + layout
  Cards.swift                     Summary / skills / bosses / activities cards
  PlayerViewModel.swift           State & data loading
  WOMService.swift                Wise Old Man API client
  Models.swift                    Codable response models
  Metrics.swift                   Metric names, ordering & number formatting
  Assets.xcassets                 App icon & accent colour
```

Not affiliated with Jagex or Wise Old Man. Data © their respective owners.
