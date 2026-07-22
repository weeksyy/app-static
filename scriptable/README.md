# OSRS Daily XP — Scriptable widget

A live **Home Screen widget** for iPhone that shows today's XP gained toward a
daily target, without needing a Mac or the App Store. It uses the free
[Scriptable](https://scriptable.app) app, which runs JavaScript as a widget and
can fetch directly from the Wise Old Man API.

> A Progressive Web App (the Home Screen icon) **cannot** provide a real iOS
> widget — those are native-only. Scriptable is the no-Mac way to get one.

![medium widget: a purple progress ring with today's XP beside it]

## Setup

1. Install **Scriptable** from the App Store (free).
2. Open Scriptable → tap **+** (new script) → paste the contents of
   [`OSRS-Daily-XP.js`](OSRS-Daily-XP.js) → rename it to **OSRS Daily XP**.
3. At the top of the script, edit two lines:
   ```js
   const RSN = "weeksy";            // your RuneScape name
   const DAILY_TARGET = 1000000;    // daily XP goal
   ```
4. Tap ▶︎ to test — it should present the widget with your data.
5. Long-press your Home Screen → **+** → **Scriptable** → choose the **Medium**
   size → add it.
6. Long-press the new widget → **Edit Widget** → set **Script** to
   *OSRS Daily XP*.

That's it. The widget refreshes itself roughly every 30 minutes (iOS decides the
exact timing), and "today" means since local midnight — matching the app and
WOM's daily XP graph.

## Notes

- Your player must be tracked on Wise Old Man. If the widget shows 0 or an
  error, open the web app once and tap **Update**, then wait for the widget to
  refresh.
- Numbers use the same abbreviations as the app (e.g. `+132k`, `1.0M`).
- To change your name or target later, just edit those two lines in Scriptable.
