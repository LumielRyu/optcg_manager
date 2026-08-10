const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const source = fs.readFileSync('api/optcg-cards.js', 'utf8');

test('loads both Supabase catalog sources concurrently', () => {
  assert.match(source, /Promise\.allSettled\(\[/);
  assert.match(source, /fetchPromotionalCards\(\{/);
  assert.match(source, /fetchCatalogCards\(\{/);
  assert.match(source, /message: 'optcg_catalog_loaded'/);
});

test('serves catalog responses from browser and CDN cache', () => {
  assert.match(source, /max-age=300/);
  assert.match(source, /s-maxage=900/);
  assert.match(source, /stale-while-revalidate=86400/);
});
