/* WILDCARD service worker v2 — whitelist-only.
   v1 intercepted EVERY same-origin GET, which broke large binary downloads
   (the APK): the stream-tee into CacheStorage aborted at finalization, and
   resume (Range) retries got answered from cache with a full-body 200.
   v2 only ever touches the app shell; everything else goes straight to the
   network untouched. */
const CACHE = 'wildcard-v2';
const SHELL = ['/', '/index.html', '/manifest.json', '/icon-192.png', '/icon-512.png', '/icon-maskable-512.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(['/'])).then(() => self.skipWaiting()));
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
