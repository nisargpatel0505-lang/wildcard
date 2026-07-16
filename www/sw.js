/* WILDCARD service worker v5 — whitelist-only.
   v1 intercepted EVERY same-origin GET, which broke large binary downloads
   (the APK): the stream-tee into CacheStorage aborted at finalization, and
   resume (Range) retries got answered from cache with a full-body 200.
   v2 only ever touches the app shell; everything else goes straight to the
   network untouched. */
const CACHE = 'wildcard-v7';
const SHELL = [
  '/', '/index.html', '/manifest.json', '/icon-192.png', '/icon-512.png', '/icon-maskable-512.png',
  '/assets/art/backgrounds/wildcard-main-menu-palace.webp',
  '/assets/art/backgrounds/wildcard-the-house-boss-room.webp',
  '/assets/art/backgrounds/wildcard-sly-shop-backroom.webp',
  '/assets/art/backgrounds/wildcard-royal-vault-chest-room.webp',
  '/assets/art/backgrounds/wildcard-endless-victory-cosmos.webp',
  '/assets/art/backgrounds/wildcard-theme-neon-heist.webp',
  '/assets/art/backgrounds/wildcard-theme-moonlit-masquerade.webp',
  '/assets/art/backgrounds/wildcard-theme-ember-casino.webp',
  '/assets/art/backgrounds/wildcard-theme-emerald-throne.webp',
  '/assets/art/backgrounds/wildcard-theme-haunted-carnival.webp',
  '/assets/art/backgrounds/wildcard-theme-clockwork-royale.webp',
  '/assets/art/wildcard-logo-v692.webp',
  '/assets/audio/bit-shift-kevin-macleod-115bpm.mp3'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET') return;
  if (u.origin !== self.location.origin) return;
  if (!SHELL.includes(u.pathname)) return;          // downloads, /api/, .apk, anything else: hands off
  if (e.request.headers.get('range')) return;       // never answer partial-content requests from cache
  e.respondWith(
    fetch(e.request).then(r => {
      if (r.ok && r.status === 200) {
        const cp = r.clone();
        caches.open(CACHE).then(c => c.put(e.request, cp));
      }
      return r;
    }).catch(() => caches.match(e.request, { ignoreSearch: true }))
  );
});
