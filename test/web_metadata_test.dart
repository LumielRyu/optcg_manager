import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web entry point exposes complete SEO and social metadata', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('<html lang="pt-BR">'));
    expect(html, contains('name="viewport"'));
    expect(html, contains('name="robots"'));
    expect(
      html,
      contains('<link rel="canonical" href="https://tcgbh.vercel.app/">'),
    );
    expect(html, contains('property="og:title"'));
    expect(html, contains('property="og:image"'));
    expect(html, contains('assets/editorial/marketplace_hero.png'));
    expect(html, contains('name="twitter:card" content="summary_large_image"'));
    expect(html, contains('type="application/ld+json"'));
    expect(html, contains("window.addEventListener('hashchange'"));
    expect(html, contains("window.addEventListener('flutter-first-frame'"));
    expect(
      html,
      contains(
        ".register('pwa_service_worker.js', { updateViaCache: 'none' })",
      ),
    );
    expect(
      html,
      contains(
        "const cacheResetVersion = '2026-08-09-one-piece-catalog-v6'",
      ),
    );
    expect(File('assets/editorial/marketplace_hero.png').existsSync(), isTrue);

    final structuredData = RegExp(
      r'<script type="application/ld\+json">\s*([\s\S]*?)\s*</script>',
    ).firstMatch(html);
    expect(structuredData, isNotNull);
    final json = jsonDecode(structuredData!.group(1)!) as Map<String, dynamic>;
    expect(json['@type'], 'WebApplication');
    expect(json['url'], 'https://tcgbh.vercel.app/');
    expect(json['inLanguage'], 'pt-BR');
  });

  test('custom PWA worker caches the shell but bypasses private APIs', () {
    final worker = File('web/pwa_service_worker.js').readAsStringSync();
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

    expect(worker, contains("const CACHE_NAME = 'optcg-shell-v6'"));
    expect(worker, contains('const NETWORK_FIRST_ASSETS = new Set(['));
    expect(worker, contains("fetch(request, { cache: 'no-store' })"));
    expect(worker, contains("url.pathname.startsWith('/api/')"));
    expect(worker, contains("caches.match('/index.html')"));
    expect(worker, contains("'/main.dart.js'"));
    expect(worker, contains("'/canvaskit/chromium/canvaskit.wasm'"));
    expect(bootstrap, contains("canvasKitBaseUrl: 'canvaskit/'"));
  });

  test(
    'PWA manifest supports installation, shortcuts and all orientations',
    () {
      final manifest =
          jsonDecode(File('web/manifest.json').readAsStringSync())
              as Map<String, dynamic>;

      expect(manifest['id'], '/');
      expect(manifest['start_url'], '/');
      expect(manifest['scope'], '/');
      expect(manifest['display'], 'standalone');
      expect(manifest['lang'], 'pt-BR');
      expect(manifest.containsKey('orientation'), isFalse);

      final shortcuts = manifest['shortcuts'] as List<dynamic>;
      expect(shortcuts, hasLength(4));
      expect(
        shortcuts.map((item) => (item as Map<String, dynamic>)['url']),
        containsAll(<String>[
          '/#/weeklies',
          '/#/marketplace',
          '/#/library',
          '/#/products',
        ]),
      );

      final icons = manifest['icons'] as List<dynamic>;
      for (final icon in icons.cast<Map<String, dynamic>>()) {
        expect(File('web/${icon['src']}').existsSync(), isTrue);
      }
    },
  );

  test('robots and sitemap advertise the canonical production URL', () {
    final robots = File('web/robots.txt').readAsStringSync();
    final sitemap = File('web/sitemap.xml').readAsStringSync();

    expect(robots, contains('Allow: /'));
    expect(robots, contains('Sitemap: https://tcgbh.vercel.app/sitemap.xml'));
    expect(sitemap, contains('<loc>https://tcgbh.vercel.app/</loc>'));
  });
}
