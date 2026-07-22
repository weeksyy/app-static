// OSRS Daily XP — Scriptable widget
// A medium Home Screen widget showing today's XP gained toward a daily target,
// as a progress ring. Fetches live from the Wise Old Man API. No Mac needed.
//
// SETUP (iPhone):
//  1. Install the free "Scriptable" app from the App Store.
//  2. Open Scriptable → tap + → paste this whole file → name it "OSRS Daily XP".
//  3. Long-press your Home Screen → + → Scriptable → pick the MEDIUM size.
//  4. Long-press the new widget → Edit Widget → Script: "OSRS Daily XP".
//  5. (Optional) set "When Interacting" to Run Script.
//
// EDIT THESE TWO LINES for your account:
const RSN = "weeksy";            // your RuneScape name
const DAILY_TARGET = 1000000;    // daily XP goal
// ---------------------------------------------------------------------------

// Theme (matches the web app)
const BG_TOP = "#1b1b3f", BG_BOT = "#141430";
const PURPLE = "#6c5ce7", GREEN = "#16c784", TRACK = "#48447c";
const WHITE = "#ffffff", MUTED = "#9a9ac6", LIGHT_GREEN = "#9dffce";

// --- Fetch today's overall XP gained (local midnight -> now) ---
async function fetchTodayGain(name) {
  const start = new Date(); start.setHours(0, 0, 0, 0);
  const end = new Date();
  const url = "https://api.wiseoldman.net/v2/players/" + encodeURIComponent(name.trim()) +
    "/gained?startDate=" + encodeURIComponent(start.toISOString()) +
    "&endDate=" + encodeURIComponent(end.toISOString());
  const req = new Request(url);
  req.headers = { "Accept": "application/json" };
  const data = await req.loadJSON();
  return Math.max(0, data?.data?.skills?.overall?.experience?.gained || 0);
}

// --- Number formatting: 13.0M / 830k, exact under 100k ---
function short(n) {
  n = Math.round(n) || 0;
  const a = Math.abs(n);
  let s;
  if (a >= 1e6) s = (a / 1e6).toFixed(1) + "M";
  else if (a >= 1e5) s = Math.round(a / 1e3) + "k";
  else s = a.toLocaleString("en-US");
  return (n < 0 ? "-" : "") + s;
}

// --- Draw the progress ring as an image ---
function ringImage(pct, reached, size, lineWidth) {
  const ctx = new DrawContext();
  ctx.size = new Size(size, size);
  ctx.opaque = false;
  ctx.respectScreenScale = true;
  const r = (size - lineWidth) / 2;
  const cx = size / 2, cy = size / 2;

  const dot = (deg, color) => {
    const rad = (deg - 90) * Math.PI / 180;
    const x = cx + r * Math.cos(rad) - lineWidth / 2;
    const y = cy + r * Math.sin(rad) - lineWidth / 2;
    ctx.setFillColor(new Color(color));
    ctx.fillEllipse(new Rect(x, y, lineWidth, lineWidth));
  };

  for (let a = 0; a < 360; a += 1) dot(a, TRACK);             // track
  const end = Math.max(0, Math.min(1, pct)) * 360;
  const col = reached ? GREEN : PURPLE;
  for (let a = 0; a <= end; a += 1) dot(a, col);              // progress

  // centre label
  const fs = size * 0.22;
  ctx.setTextAlignedCenter();
  ctx.setFont(Font.boldSystemFont(fs));
  ctx.setTextColor(new Color(WHITE));
  ctx.drawTextInRect(Math.round(pct * 100) + "%", new Rect(0, cy - fs * 0.75, size, fs * 1.6));
  return ctx.getImage();
}

// --- Build the widget ---
function buildWidget(gained, error) {
  const w = new ListWidget();
  const g = new LinearGradient();
  g.colors = [new Color(BG_TOP), new Color(BG_BOT)];
  g.locations = [0, 1];
  w.backgroundGradient = g;
  w.setPadding(16, 18, 16, 18);
  w.refreshAfterDate = new Date(Date.now() + 30 * 60 * 1000); // ~30 min

  if (error) {
    const t = w.addText("⚠️ " + error);
    t.font = Font.mediumSystemFont(14);
    t.textColor = new Color(WHITE);
    const s = w.addText("Pull down in Scriptable to retry.");
    s.font = Font.systemFont(12); s.textColor = new Color(MUTED);
    return w;
  }

  const pct = DAILY_TARGET > 0 ? Math.min(1, gained / DAILY_TARGET) : 0;
  const reached = gained >= DAILY_TARGET;
  const remaining = Math.max(0, DAILY_TARGET - gained);

  const row = w.addStack();
  row.centerAlignContent();

  const img = row.addImage(ringImage(pct, reached, 220, 26));
  img.imageSize = new Size(104, 104);

  row.addSpacer(18);

  const col = row.addStack();
  col.layoutVertically();

  const title = col.addText("🧙 " + RSN);
  title.font = Font.boldSystemFont(18);
  title.textColor = new Color(WHITE);
  title.lineLimit = 1;

  col.addSpacer(6);
  const xp = col.addText("+" + short(gained) + " XP");
  xp.font = Font.boldSystemFont(16);
  xp.textColor = new Color(LIGHT_GREEN);

  col.addSpacer(1);
  const lbl = col.addText("today");
  lbl.font = Font.systemFont(12);
  lbl.textColor = new Color(MUTED);

  col.addSpacer(6);
  const tgt = col.addText("Target " + short(DAILY_TARGET));
  tgt.font = Font.systemFont(13);
  tgt.textColor = new Color(MUTED);

  col.addSpacer(2);
  const foot = col.addText(reached ? "✅ Reached" : short(remaining) + " to go");
  foot.font = Font.semiboldSystemFont(13);
  foot.textColor = new Color(reached ? GREEN : WHITE);

  return w;
}

// --- Run ---
let widget;
try {
  const gained = await fetchTodayGain(RSN);
  widget = buildWidget(gained, null);
} catch (e) {
  widget = buildWidget(0, "Couldn't load " + RSN);
}

if (config.runsInWidget) {
  Script.setWidget(widget);
} else {
  widget.presentMedium();
}
Script.complete();
