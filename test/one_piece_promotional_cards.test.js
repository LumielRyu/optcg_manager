const assert = require('node:assert/strict');
const test = require('node:test');

const {
  baseCardCode,
  fetchPromotionalCards,
  mergePromotionalCards,
} = require('../server/one-piece-promotional-cards');

test('extracts the original code from promotional variants', () => {
  assert.equal(baseCardCode('P-001-AA'), 'P-001');
  assert.equal(baseCardCode('OP01-001-RE'), 'OP01-001');
  assert.equal(baseCardCode('DON-001-3A'), 'DON-001');
});

test('adds Liga promotional variants and reuses base card metadata', () => {
  const cards = [
    {
      card_set_id: 'P-001',
      card_name: 'Monkey D. Luffy',
      card_image: 'https://api.example/p-001.jpg',
      card_color: 'Red',
      card_type: 'Leader',
      rarity: 'P',
    },
  ];
  const merged = mergePromotionalCards(cards, [
    {
      card_code: 'P-001-AA',
      card_name: 'Monkey D. Luffy (Alternate Art)',
      image_url: 'https://repo.example/p-001-aa.jpg',
    },
  ]);

  assert.equal(merged.length, 2);
  assert.deepEqual(merged[1], {
    card_set_id: 'P-001-AA',
    card_name: 'Monkey D. Luffy (Alternate Art)',
    card_image: 'https://repo.example/p-001-aa.jpg',
    card_color: 'Red',
    card_type: 'Leader',
    rarity: 'P',
    sub_types: '',
    card_text: '',
    attribute: '',
    set_id: 'P',
    set_name: 'Promotion Cards (PC-01)',
  });
});

test('replaces an incomplete upstream promo with the canonical Liga variant', () => {
  const cards = [
    {
      card_set_id: 'OP12-028',
      card_name: 'Kouzuki Hiyori',
      card_image: 'https://api.example/op12-028.jpg',
      card_color: 'Green',
      card_type: 'Character',
      rarity: 'R',
    },
    {
      card_set_id: 'OP12-028',
      card_name: 'Kouzuki Hiyori (Winner Pack 2026 Vol. 1)',
      card_image: '',
      set_name: 'One Piece Promotion Cards',
    },
  ];

  const merged = mergePromotionalCards(cards, [
    {
      card_code: 'OP12-028-WP',
      card_name: 'Kouzuki Hiyori (Winner Pack 2026 Vol. 1)',
      image_url: 'https://repo.example/op12-028-wp.jpg',
    },
  ]);

  assert.equal(merged.length, 2);
  assert.equal(merged[1].card_set_id, 'OP12-028-WP');
  assert.equal(merged[1].card_image, 'https://repo.example/op12-028-wp.jpg');
  assert.equal(merged[1].card_color, 'Green');
  assert.equal(merged[1].card_type, 'Character');
});

test('reads every Supabase page from the promotional edition', async () => {
  const requests = [];
  const rows = await fetchPromotionalCards({
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'public-key',
    fetchImpl: async (url) => {
      requests.push(url);
      const offset = Number(url.searchParams.get('offset'));
      return {
        ok: true,
        json: async () =>
          offset === 0
            ? Array.from({ length: 1000 }, (_, index) => ({
                card_code: `P-${String(index).padStart(3, '0')}`,
              }))
            : [{ card_code: 'P-1000' }],
      };
    },
  });

  assert.equal(rows.length, 1001);
  assert.equal(requests.length, 2);
  assert.equal(requests[0].searchParams.get('edition_code'), 'eq.PC-01');
  assert.equal(requests[1].searchParams.get('offset'), '1000');
});

test('retries a temporary Supabase failure before returning promos', async () => {
  let attempts = 0;
  const rows = await fetchPromotionalCards({
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'public-key',
    retryDelayMs: 0,
    fetchImpl: async () => {
      attempts += 1;
      if (attempts === 1) return { ok: false, status: 500 };
      return {
        ok: true,
        status: 200,
        json: async () => [{ card_code: 'OP12-028-WP' }],
      };
    },
  });

  assert.equal(attempts, 2);
  assert.equal(rows[0].card_code, 'OP12-028-WP');
});
