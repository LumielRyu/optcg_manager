'use strict';

const CACHE_NAME = 'optcg-shell-v5';
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
  '/main.dart.js',
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/assets/AssetManifest.bin.json',
  '/assets/FontManifest.json',
  '/assets/fonts/MaterialIcons-Regular.otf',
  '/assets/packages/cupertino_icons/assets/CupertinoIcons.ttf',
  '/assets/assets/editorial/scanner_card_stack.png',
  '/canvaskit/canvaskit.js',
  '/canvaskit/canvaskit.wasm',
  '/canvaskit/chromium/canvaskit.js',
  '/canvaskit/chromium/canvaskit.wasm',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(async (cache) => {
      await Promise.all(
        CORE_ASSETS.map(async (asset) => {
          try {
            const response = await fetch(asset, { cache: 'reload' });
            if (response.ok) await cache.put(asset, response);
          } catch (_) {
            // A single optional asset must not prevent installation.
          }
        }),
      );
      await self.skipWaiting();
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
      .then(() => self.clients.claim()),
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
      fetch(request, { cache: 'no-store' })
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
      fetch(request, { cache: 'no-store' })
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
