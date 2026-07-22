# OSRS Stats — push notifications backend (Cloudflare Worker)

This tiny Worker stores your phone's push subscription and runs on a cron to
send notifications: **birdhouse timer**, **daily reminder / XP summary**,
**daily-goal-hit**, and **skill-goal-reached**. It's free on Cloudflare's plan.

You deploy it once from a **desktop browser** (Cloudflare's dashboard). No
command line required.

---

## What you need

- A free [Cloudflare](https://dash.cloudflare.com/sign-up) account.
- Two values your assistant gave you in chat:
  - **VAPID public key** (already baked into the app and `wrangler.toml`)
  - **VAPID private key (JWK)** — keep this secret, you'll paste it as an
    encrypted secret below. **Do not commit it anywhere.**

---

## Deploy with the dashboard (recommended)

1. **Create the Worker**
   - Cloudflare dashboard → **Workers & Pages** → **Create** → **Create Worker**.
   - Name it e.g. `osrs-stats-push` → **Deploy** (accept the default hello-world).
   - Click **Edit code**, delete everything, paste the contents of
     [`worker.js`](worker.js), then **Deploy**.

2. **Create a KV namespace**
   - **Storage & Databases → KV → Create a namespace**, name it `osrs-subs`.

3. **Bind KV to the Worker**
   - Your Worker → **Settings → Bindings → Add → KV namespace**.
   - **Variable name:** `SUBS`  → **KV namespace:** `osrs-subs` → Save.

4. **Add variables & the secret**
   - Your Worker → **Settings → Variables and Secrets**:
     - Add variable **`VAPID_PUBLIC`** = the public key (plaintext).
     - Add variable **`VAPID_SUBJECT`** = `mailto:your-email@example.com`.
     - Add **secret** **`VAPID_PRIVATE_JWK`** = the JWK string from chat
       (choose "Encrypt"/secret, not plaintext).

5. **Add the cron trigger**
   - Your Worker → **Settings → Triggers → Cron Triggers → Add** → `* * * * *`
     (every minute) → Save.

6. **Grab the URL & connect the app**
   - Copy your Worker URL (looks like `https://osrs-stats-push.<you>.workers.dev`).
   - Open the OSRS Stats web app **from your Home Screen icon** → tap the 🔔 →
     paste the URL into **Backend URL**, enter your **RSN** → **Enable
     notifications** → allow the prompt → **Send test**. You should get a push.

---

## CLI alternative (if you use wrangler)

```bash
npm i -g wrangler
wrangler kv namespace create SUBS      # paste the id into wrangler.toml
wrangler secret put VAPID_PRIVATE_JWK  # paste the JWK when prompted
wrangler deploy
```

`VAPID_PUBLIC` and `VAPID_SUBJECT` are already in `wrangler.toml`.

---

## Notes & limits

- **iOS:** Web Push only works for the app **installed to the Home Screen**
  (iOS 16.4+), not in a Safari tab. Allow the notification permission prompt.
- The Worker sends **payload-less** pushes; the app's service worker fetches the
  message text from the Worker's `/pending` endpoint and shows it.
- "Today" for XP checks uses your **timezone** (sent by the app), matching the
  daily XP graph.
- Free-tier friendly: it only writes to KV when something actually changes, and
  polls Wise Old Man at most every ~10 minutes per player.
- Endpoints: `POST /register`, `POST /timer`, `POST /pending`, `POST /test`,
  `POST /unregister`, `GET /publicKey`.
- To rotate keys, generate a new VAPID pair, update `VAPID_PUBLIC` in the app +
  Worker and `VAPID_PRIVATE_JWK` secret, and re-enable notifications on the phone.
