// Service worker: offline app-shell cache + Web Push handling.
const CACHE = "osrs-stats-v6";
const ASSETS = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
  "./icons/apple-touch-icon.png",
  "./icons/favicon-32.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);
  if (url.origin !== location.origin || event.request.method !== "GET") return;
  event.respondWith(
    caches.match(event.request).then((hit) => {
      if (hit) return hit;
      return fetch(event.request)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(event.request, copy));
          return res;
        })
        .catch(() => caches.match("./index.html"));
    })
  );
});

// --- Push ---
// We use payload-less "tickle" pushes: on receiving one, fetch the pending
// notification(s) for this device from the backend, then show them. iOS
// requires that every push shows a notification, so we always show something.
async function readCfg(key) {
  try {
    const c = await caches.open("cfg");
    const r = await c.match(key);
    return r ? (await r.text()) : "";
  } catch (e) { return ""; }
}

self.addEventListener("push", (event) => {
  event.waitUntil((async () => {
    let items = [];
    try {
      // If a payload was sent, use it directly.
      if (event.data) {
        const d = event.data.json();
        items = Array.isArray(d) ? d : [d];
      } else {
        const backend = await readCfg("/backend-url");
        const sub = await self.registration.pushManager.getSubscription();
        if (backend && sub) {
          const r = await fetch(backend.replace(/\/$/, "") + "/pending", {
            method: "POST",
            headers: { "content-type": "application/json" },
            body: JSON.stringify({ endpoint: sub.endpoint }),
          });
          if (r.ok) items = (await r.json()).items || [];
        }
      }
    } catch (e) { /* fall through to default */ }

    if (!items.length) items = [{ title: "OSRS Stats", body: "You have an update." }];
    for (const it of items) {
      await self.registration.showNotification(it.title || "OSRS Stats", {
        body: it.body || "",
        tag: it.tag,
        icon: "icons/icon-192.png",
        badge: "icons/icon-192.png",
        data: it.data || {},
      });
    }
  })());
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((cl) => {
      for (const c of cl) { if ("focus" in c) return c.focus(); }
      if (self.clients.openWindow) return self.clients.openWindow("./");
    })
  );
});
