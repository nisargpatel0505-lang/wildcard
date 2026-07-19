/* WILDCARD service worker v5 — whitelist-only.
   v1 intercepted EVERY same-origin GET, which broke large binary downloads
   (the APK): the stream-tee into CacheStorage aborted at finalization, and
   resume (Range) retries got answered from cache with a full-body 200.
   v2 only ever touches the app shell; everything else goes straight to the
   network untouched. */
const CACHE = 'wildcard-v14';
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
  '/assets/art/backgrounds/wildcard-cosmic-base.webp',
  '/assets/art/backgrounds/wildcard-cosmic-wilds.webp',
  '/assets/art/backgrounds/wildcard-menu-keyart.png',
  '/assets/art/sly/sly-expression-grid.webp',
  '/assets/art/sly/sly-skins-grid.webp',
  '/assets/art/sly/sly-stage-actions-grid.webp',
  '/assets/video/sly-single-tear.mp4',
  '/assets/art/wildcard-logo-v692.webp',
  '/assets/art/wildcard-logo-boot.webp',
  '/fonts/bungee-regular.ttf',
  '/fonts/space-grotesk-400.ttf',
  '/fonts/space-grotesk-500.ttf',
  '/fonts/space-grotesk-700.ttf',
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
  const range = e.request.headers.get('range');
  if (range && u.pathname === '/assets/video/sly-single-tear.mp4') {
    // Media elements commonly request MP4 byte ranges. This cinematic is tiny
    // and precached, so serve a standards-compliant slice while offline without
    // changing the deliberate Range bypass for APKs or other downloads.
    e.respondWith(
      caches.match(u.pathname).then(cached => cached || fetch(new Request(u.href, { credentials: 'same-origin' })))
        .then(async full => {
          const bytes = await full.arrayBuffer();
          const size = bytes.byteLength;
          const match = /^bytes=(\d+)-(\d*)$/i.exec(range);
          if (!match) return new Response(bytes, { status: 200, headers: full.headers });
          const start = Number(match[1]);
          const requestedEnd = match[2] ? Number(match[2]) : size - 1;
          if (!Number.isFinite(start) || start >= size || start < 0) {
            return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${size}` } });
          }
          const end = Math.min(size - 1, Math.max(start, requestedEnd));
          const chunk = bytes.slice(start, end + 1);
          return new Response(chunk, {
            status: 206,
            headers: {
              'Accept-Ranges': 'bytes',
              'Content-Range': `bytes ${start}-${end}/${size}`,
              'Content-Length': String(chunk.byteLength),
              'Content-Type': full.headers.get('Content-Type') || 'video/mp4'
            }
          });
        })
    );
    return;
  }
  if (range) return;                                // never answer other partial-content requests from cache
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
