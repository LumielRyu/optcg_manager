'use strict';

const CACHE_NAME = 'optcg-shell-v8';
const NETWORK_FIRST_ASSETS = new Set([
  '/',
  '/index.html',
  '/flutter.js',
  '/flutter_bootstrap.js',
  '/main.dart.js',
  '/version.json',
  '/assets/AssetManifest.bin',
  '/assets/AssetManifest.bin.json',
  '/assets/FontManifest.json',
]);
const CORE_ASSETS = [
  '/',
  '/index.html',
  '/flutter_bootstrap.js',
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(async (cache) => {
      await Promise.all(
        CORE_ASSETS.map(async (asset) => {
          try {
            const response = await fetch(asset, { cache: 'no-cache' });
            if (response.ok) await cache.put(asset, response);
          } catch (_) {
            // A single optional asset must not prevent installation.
          }
        }),
      );
      // Never replace the worker controlling an open Flutter session. The app
      // loads route modules lazily, so mixing an old main bundle with assets
      // from a new deployment can break navigation on mobile browsers.
    }),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((names) =>
        Promise.all(
          names
            .filter((name) => name.startsWith('optcg-shell-') && name !== CACHE_NAME)
            .map((name) => caches.delete(name)),
        ),
      )
      // Activation happens naturally after every tab using the previous
      // version has closed. The next navigation is then fully version-aligned.
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin || url.pathname.startsWith('/api/')) {
    return;
  }

  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request, { cache: 'no-cache' })
        .then((response) => {
          if (response.ok) {
            const copy = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put('/index.html', copy));
          }
          return response;
        })
        .catch(async () => {
          return (await caches.match('/index.html')) || caches.match('/');
        }),
    );
    return;
  }

  if (NETWORK_FIRST_ASSETS.has(url.pathname)) {
    event.respondWith(
      fetch(request, { cache: 'no-cache' })
        .then((response) => {
          if (response.ok && response.type === 'basic') {
            const copy = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, copy));
          }
          return response;
        })
        .catch(() => caches.match(request)),
    );
    return;
  }

  event.respondWith(
    caches.match(request).then((cached) => {
      const network = fetch(request).then((response) => {
        if (response.ok && response.type === 'basic') {
          const copy = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(request, copy));
        }
        return response;
      });
      if (cached) {
        event.waitUntil(network.catch(() => undefined));
        return cached;
      }
      return network;
    }),
  );
});
