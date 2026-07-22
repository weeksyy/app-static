# OSRS Stats — Wise Old Man

Look up an Old School RuneScape player and see their **current stats**, **XP
gained over a day** (or week/month/year), and **boss kill counts & activity
scores** — all from the [Wise Old Man](https://wiseoldman.net) API, so you don't
have to open the website.

There are three front-ends in this repo:

- **`docs/`** — an installable web app (works on any phone with no Mac needed).
- **`scriptable/`** — a live Home Screen widget for iPhone via the free
  [Scriptable](https://scriptable.app) app (no Mac needed). See
  [`scriptable/README.md`](scriptable/README.md).
- **`WiseOldManStats/` + `XPWidget/`** — a native SwiftUI iOS app with a Home
  Screen widget (requires a Mac + Xcode to build).

## Installable web app (no Mac required)

The `docs/` folder is a self-contained web app that calls the Wise Old Man API
directly from the browser. It can be added to your phone's Home Screen so it
launches full-screen like a real app, with its own icon and offline app-shell.

### Host it with GitHub Pages

1. On GitHub, open **Settings → Pages**.
2. **Source:** *Deploy from a branch*. **Branch:** the repo's default branch,
   **Folder:** `/docs`. Save.
3. Wait ~1 minute; your app is live at `https://<user>.github.io/app-static/`.
4. On your iPhone, open that URL in Safari → **Share** → **Add to Home Screen**.

Recent searches and your daily XP target are stored on the device via
`localStorage`.

## Home Screen widget without a Mac (Scriptable)

A PWA can't provide a real iOS widget, but the free **Scriptable** app can run a
JavaScript widget with live data. [`scriptable/OSRS-Daily-XP.js`](scriptable/OSRS-Daily-XP.js)
is a medium widget showing today's XP as a progress ring toward a daily target.
Setup instructions are in [`scriptable/README.md`](scriptable/README.md).

## Native iOS app

## Features

- Search any RuneScape name.
- **Summary card:** combat level, total level, total XP, EHP, EHB, and XP gained
  in the selected period — plus a **daily XP target** progress bar.
- **Skills table:** level, experience, rank and gained XP per skill.
- **Bosses:** kill counts, rank and kills gained.
- **Activities & clues:** scores, rank and gained.
- Period switch (Day / Week / Month / Year) for all gains.
- **Pull to refresh** to re-fetch the current player.
- **Recent searches** — tap a name to jump straight back to it (stored on device).
- **Update** button to track a new player or pull a fresh snapshot from the
  official hiscores.
- **Home Screen widget** ("OSRS Daily XP") showing a progress ring of today's XP
  toward a target. Small and medium sizes. Configure the name and target by
  long-pressing the widget → **Edit Widget**; it refreshes itself about every
  30 minutes.

### Setting the daily target

- **In-app:** tap the 🎯 target button in the top-right to set the target that
  drives the in-app progress bar.
- **Widget:** long-press the widget → *Edit Widget* → set the RuneScape name and
  daily target. The widget keeps its own name/target so it works without opening
  the app.

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
| XP / KC gained over a rolling period | `GET /players/{username}/gained?period=week` |
| XP gained **today** (calendar day) | `GET /players/{username}/gained?startDate=…&endDate=…` |
| Track / refresh a player | `POST /players/{username}` |

> **Today vs. last-24h:** the *Day* view uses a custom `startDate`/`endDate`
> range from local midnight to now — matching WOM's daily XP graph — rather than
> the rolling-24h `period=day`, which would include yesterday evening's XP.

Networking lives in [`WOMService.swift`](Shared/WOMService.swift),
the response models in [`Models.swift`](Shared/Models.swift), and the
UI in [`ContentView.swift`](WiseOldManStats/ContentView.swift) /
[`Cards.swift`](WiseOldManStats/Cards.swift). The same endpoints power the web
app in [`docs/index.html`](docs/index.html).

## Project layout

```
WiseOldManStats.xcodeproj        Xcode project (app + widget targets)
Shared/                           Code shared by the app and the widget
  Models.swift                    Codable response models
  WOMService.swift                Wise Old Man API client
WiseOldManStats/                  App target
  WiseOldManStatsApp.swift        App entry point
  ContentView.swift               Search UI, recent searches, target sheet
  Cards.swift                     Summary / skills / bosses / activities cards
  PlayerViewModel.swift           State, data loading & recent searches
  Metrics.swift                   Metric names, ordering & number formatting
  Assets.xcassets                 App icon & accent colour
XPWidget/                         Widget extension target
  XPWidgetBundle.swift            Widget bundle entry point
  XPWidget.swift                  Timeline provider, config intent & views
XPWidget-Info.plist               Widget extension Info.plist
```

> The widget is a separate build target that shares `Shared/Models.swift` and
> `Shared/WOMService.swift` with the app, and fetches its own data from Wise Old
> Man, so it doesn't need the app to be running.

Not affiliated with Jagex or Wise Old Man. Data © their respective owners.
