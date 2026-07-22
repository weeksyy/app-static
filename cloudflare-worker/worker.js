// OSRS Stats — push backend (Cloudflare Worker)
// Stores each device's push subscription + settings in KV, runs on a cron to
// send: birdhouse timers, a daily reminder/summary, daily-goal-hit alerts, and
// skill-goal-reached alerts. Uses payload-less Web Push (VAPID) — the service
// worker fetches the notification text from /pending when tickled.
//
// Bindings (see wrangler.toml / dashboard):
//   KV namespace:  SUBS
//   Vars:          VAPID_PUBLIC, VAPID_SUBJECT
//   Secret:        VAPID_PRIVATE_JWK   (the JWK JSON string)

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "content-type",
};
const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json", ...CORS } });

// ---- base64url / crypto helpers ----
const b64url = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const enc = new TextEncoder();

async function sha256b64(str) {
  const d = await crypto.subtle.digest("SHA-256", enc.encode(str));
  return b64url(d);
}

let _vapidKey = null;
async function vapidKey(env) {
  if (_vapidKey) return _vapidKey;
  const jwk = JSON.parse(env.VAPID_PRIVATE_JWK);
  _vapidKey = await crypto.subtle.importKey("jwk", jwk, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  return _vapidKey;
}

async function vapidJWT(aud, env) {
  const header = b64url(enc.encode(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const payload = b64url(enc.encode(JSON.stringify({
    aud, exp: Math.floor(Date.now() / 1000) + 43200, sub: env.VAPID_SUBJECT || "mailto:osrs@example.com",
  })));
  const input = header + "." + payload;
  const sig = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, await vapidKey(env), enc.encode(input));
  return input + "." + b64url(sig);
}

// Send a payload-less push. Returns HTTP status (201 = ok; 404/410 = expired).
async function sendPush(endpoint, env) {
  const aud = new URL(endpoint).origin;
  const jwt = await vapidJWT(aud, env);
  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      TTL: "2419200",
      Authorization: `vapid t=${jwt}, k=${env.VAPID_PUBLIC}`,
    },
  });
  return res.status;
}

// ---- KV records ----
const keyFor = async (endpoint) => "sub:" + (await sha256b64(endpoint));
const loadRec = async (env, endpoint) => JSON.parse((await env.SUBS.get(await keyFor(endpoint))) || "null");
async function saveRec(env, rec) {
  rec.updatedAt = Date.now();
  await env.SUBS.put("sub:" + (await sha256b64(rec.endpoint)), JSON.stringify(rec));
}

function defaultRec(endpoint) {
  return {
    endpoint,
    settings: { rsn: "", dailyTarget: 1000000, goal: null, reminderTime: null, tz: "UTC",
      alerts: { reminder: true, summary: true, goalHit: true, skillGoal: true } },
    timers: [], pending: [],
    state: { lastDailySent: "", goalHitDate: "", skillGoalDone: false, lastWomCheck: 0 },
  };
}

// ---- HTTP ----
export default {
  async fetch(req, env) {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
    const url = new URL(req.url);
    const path = url.pathname.replace(/\/$/, "") || "/";

    if (req.method === "GET" && path === "/publicKey") return json({ key: env.VAPID_PUBLIC });

    if (req.method === "POST") {
      let body = {};
      try { body = await req.json(); } catch (e) { return json({ error: "bad json" }, 400); }
      const endpoint = body.endpoint;
      if (!endpoint) return json({ error: "no endpoint" }, 400);

      if (path === "/register") {
        const rec = (await loadRec(env, endpoint)) || defaultRec(endpoint);
        rec.endpoint = endpoint;
        if (body.settings) rec.settings = { ...rec.settings, ...body.settings,
          alerts: { ...rec.settings.alerts, ...(body.settings.alerts || {}) } };
        await saveRec(env, rec);
        return json({ ok: true });
      }
      if (path === "/timer") {
        const rec = await loadRec(env, endpoint);
        if (!rec) return json({ error: "not registered" }, 404);
        const mins = Math.max(1, Math.min(24 * 60, Number(body.minutes) || 50));
        rec.timers.push({ fireAt: Date.now() + mins * 60000, label: body.label || "Timer ready" });
        await saveRec(env, rec);
        return json({ ok: true, fireAt: Date.now() + mins * 60000 });
      }
      if (path === "/pending") {
        const rec = await loadRec(env, endpoint);
        if (!rec) return json({ items: [] });
        const items = rec.pending || [];
        if (items.length) { rec.pending = []; await saveRec(env, rec); }
        return json({ items });
      }
      if (path === "/test") {
        const rec = await loadRec(env, endpoint);
        if (!rec) return json({ error: "not registered" }, 404);
        rec.pending.push({ title: "🧙 OSRS Stats", body: "Notifications are working!" });
        await saveRec(env, rec);
        await sendPush(endpoint, env);
        return json({ ok: true });
      }
      if (path === "/unregister") {
        await env.SUBS.delete(await keyFor(endpoint));
        return json({ ok: true });
      }
    }
    return json({ error: "not found" }, 404);
  },

  async scheduled(event, env, ctx) {
    ctx.waitUntil(runCron(env));
  },
};

// ---- Cron ----
async function runCron(env) {
  const list = await env.SUBS.list({ prefix: "sub:" });
  for (const k of list.keys) {
    const rec = JSON.parse((await env.SUBS.get(k.name)) || "null");
    if (!rec) continue;
    try {
      const changed = await processRecord(env, rec);
      if (changed.deleted) { await env.SUBS.delete(k.name); continue; }
      if (changed.notify) {
        const status = await sendPush(rec.endpoint, env);
        if (status === 404 || status === 410) { await env.SUBS.delete(k.name); continue; }
      }
      if (changed.save) await saveRec(env, rec);
    } catch (e) { /* skip this record on error */ }
  }
}

async function processRecord(env, rec) {
  const now = Date.now();
  const s = rec.settings || {};
  let save = false, notify = false;

  // 1) One-off timers (birdhouse etc.)
  if (rec.timers && rec.timers.length) {
    const due = rec.timers.filter((t) => t.fireAt <= now);
    if (due.length) {
      rec.timers = rec.timers.filter((t) => t.fireAt > now);
      for (const t of due) rec.pending.push({ title: t.label || "Timer ready", body: "Time's up — back to it!", tag: "timer" });
      save = true; notify = true;
    }
  }

  // Local date/time in the user's timezone
  const tz = s.tz || "UTC";
  const nowLocal = localParts(now, tz);
  const today = nowLocal.date;

  // 2) Daily reminder / summary at the set time
  if (s.reminderTime && rec.state.lastDailySent !== today && nowLocal.hm === s.reminderTime) {
    let msg = null;
    if (s.alerts?.summary && s.rsn) {
      const g = await womGains(s.rsn, tz);
      if (g) {
        const gained = g.overall;
        const top = g.skills.slice(0, 3).map((x) => `${pretty(x.metric)} +${short(x.gained)}`).join(", ");
        msg = { title: "🧙 Daily XP", body: `+${short(gained)} today${top ? " · " + top : ""}` };
      }
    }
    if (!msg && s.alerts?.reminder) msg = { title: "🧙 OSRS Stats", body: "Don't forget your dailies!" };
    if (msg) { rec.pending.push({ ...msg, tag: "daily" }); rec.state.lastDailySent = today; save = true; notify = true; }
    else if (s.reminderTime) { rec.state.lastDailySent = today; save = true; }
  }

  // 3) Goal-hit + skill-goal — poll WOM at most every ~10 min
  const wantGoal = (s.alerts?.goalHit && s.rsn) ||
                   (s.alerts?.skillGoal && s.rsn && s.goal && !rec.state.skillGoalDone);
  if (wantGoal && now - (rec.state.lastWomCheck || 0) > 10 * 60 * 1000) {
    rec.state.lastWomCheck = now; save = true;

    if (s.alerts?.goalHit && rec.state.goalHitDate !== today) {
      const g = await womGains(s.rsn, tz);
      if (g && s.dailyTarget > 0 && g.overall >= s.dailyTarget) {
        rec.pending.push({ title: "🎯 Daily goal hit!", body: `+${short(g.overall)} XP today — nice.`, tag: "goalhit" });
        rec.state.goalHitDate = today; notify = true;
      }
    }
    if (s.alerts?.skillGoal && s.goal && !rec.state.skillGoalDone) {
      const cur = await womSkillXp(s.rsn, s.goal.metric);
      const targetXP = s.goal.type === "level" ? xpForLevel(s.goal.value) : s.goal.value;
      if (cur != null && targetXP && cur >= targetXP) {
        rec.pending.push({ title: "🏆 Goal reached!", body: goalText(s.goal), tag: "skillgoal" });
        rec.state.skillGoalDone = true; notify = true;
      }
    }
  }

  return { save, notify };
}

// ---- WOM helpers (Cloudflare can reach the API directly) ----
const WOM = "https://api.wiseoldman.net/v2";
async function womFetch(path) {
  const r = await fetch(WOM + path, { headers: { "Accept": "application/json", "User-Agent": "OSRS-Stats-Worker" } });
  if (!r.ok) return null;
  return r.json();
}
async function womGains(rsn, tz) {
  const start = new Date(localMidnightUTC(Date.now(), tz || "UTC"));
  const end = new Date();
  const d = await womFetch(`/players/${encodeURIComponent(rsn)}/gained?startDate=${encodeURIComponent(start.toISOString())}&endDate=${encodeURIComponent(end.toISOString())}`);
  if (!d) return null;
  const sk = d.data?.skills || {};
  const skills = Object.keys(sk).filter((k) => k !== "overall")
    .map((k) => ({ metric: k, gained: sk[k]?.experience?.gained || 0 }))
    .filter((x) => x.gained > 0).sort((a, b) => b.gained - a.gained);
  return { overall: Math.max(0, sk.overall?.experience?.gained || 0), skills };
}
async function womSkillXp(rsn, metric) {
  const d = await womFetch(`/players/${encodeURIComponent(rsn)}`);
  return d?.latestSnapshot?.data?.skills?.[metric]?.experience ?? null;
}

// ---- formatting ----
function short(n) {
  n = Math.round(n) || 0; const a = Math.abs(n); let s;
  if (a >= 1e6) s = (a / 1e6).toFixed(1) + "M";
  else if (a >= 1e5) s = Math.round(a / 1e3) + "k";
  else s = a.toLocaleString("en-US");
  return (n < 0 ? "-" : "") + s;
}
const NAMES = { runecrafting: "Runecraft" };
const pretty = (k) => NAMES[k] || k.charAt(0).toUpperCase() + k.slice(1);
const goalText = (g) => g.type === "level" ? `${pretty(g.metric)} level ${g.value}` : `${short(g.value)} ${pretty(g.metric)} XP`;

function tzOffsetMs(ts, tz) {
  const dtf = new Intl.DateTimeFormat("en-US", { timeZone: tz, hour12: false,
    year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit" });
  const p = {};
  for (const part of dtf.formatToParts(new Date(ts))) p[part.type] = part.value;
  const asUTC = Date.UTC(p.year, p.month - 1, p.day, p.hour === "24" ? 0 : p.hour, p.minute, p.second);
  return asUTC - ts;
}
function localMidnightUTC(ts, tz) {
  const off = tzOffsetMs(ts, tz);
  const local = new Date(ts + off);
  const midnightWall = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate(), 0, 0, 0);
  return midnightWall - off;
}
function localParts(ts, tz) {
  const fmt = new Intl.DateTimeFormat("en-CA", { timeZone: tz, hour12: false,
    year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit" });
  const p = {};
  for (const part of fmt.formatToParts(new Date(ts))) p[part.type] = part.value;
  return { date: `${p.year}-${p.month}-${p.day}`, hm: `${p.hour}:${p.minute}` };
}

const XP_TABLE = (() => {
  const t = [0, 0]; let pts = 0;
  for (let l = 1; l < 99; l++) { pts += Math.floor(l + 300 * Math.pow(2, l / 7)); t[l + 1] = Math.floor(pts / 4); }
  return t;
})();
const xpForLevel = (l) => XP_TABLE[Math.max(1, Math.min(99, l))] || 0;
