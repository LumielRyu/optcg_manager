const assert = require('node:assert/strict');
const test = require('node:test');

const {
  fetchCatalogCards,
  mergeCatalogCards,
} = require('../server/one-piece-card-catalog');

test('adds a new Liga starter card that is absent from the upstream API', () => {
  const merged = mergeCatalogCards([], [
    {
      lookup_code: 'ST31-001',
      card_code: 'ST31-001',
      card_name: 'Monkey.D.Luffy',
      image_url: 'https://repo.example/st31-001.jpg',
      edition_code: 'ST31',
      edition_name: 'Starter Deck 31: RED Monkey.D.Luffy',
    },
  ]);

  assert.deepEqual(merged, [
    {
      card_set_id: 'ST31-001',
      card_name: 'Monkey.D.Luffy',
      card_image: 'https://repo.example/st31-001.jpg',
      set_id: 'ST31',
      set_name: 'Starter Deck 31: RED Monkey.D.Luffy',
      rarity: '',
      card_color: '',
      card_type: '',
      sub_types: '',
      card_text: '',
      attribute: '',
      catalog_source: 'liga',
    },
  ]);
});

test('enriches Liga variants from an existing base card and removes cache duplicates', () => {
  const upstream = [
    {
      card_set_id: 'OP01-016',
      card_name: 'Nami',
      card_image: 'https://api.example/op01-016.jpg',
      rarity: 'R',
      card_color: 'Red',
      card_type: 'Character',
      sub_types: 'Straw Hat Crew',
      card_text: 'On Play: Draw 1 card.',
      attribute: 'Special',
    },
  ];
  const row = {
    card_code: 'OP01-016',
    card_name: 'Nami (Reprint)',
    image_url: 'https://repo.example/st31-nami.jpg',
    edition_code: 'ST31',
  };

  const merged = mergeCatalogCards(upstream, [row, { ...row }]);

  assert.equal(merged.length, 2);
  assert.equal(merged[1].set_name, 'ST31');
  assert.equal(merged[1].rarity, 'R');
  assert.equal(merged[1].card_color, 'Red');
  assert.equal(merged[1].card_type, 'Character');
  assert.equal(merged[1].catalog_source, 'liga');
});

test('removes Liga copies of the same upstream printing without merging valid variants', () => {
  const upstream = [
    {
      card_set_id: 'OP09-093',
      card_name: 'Marshall.D.Teach (093) (Alternate Art)',
      card_image: 'https://api.example/OP09-093_p1.jpg',
      set_id: 'OP-09',
      set_name: 'Emperors in the New World',
    },
    {
      card_set_id: 'OP09-093',
      card_name: 'Marshall.D.Teach (093) (Manga)',
      card_image: 'https://api.example/OP09-093_p2.jpg',
      set_id: 'OP-09',
      set_name: 'Emperors in the New World',
    },
  ];

  const merged = mergeCatalogCards(upstream, [
    {
      card_code: 'OP09-093-AA',
      card_name: 'Marshall.D.Teach (093) (Alternate Art)',
      image_url: 'https://liga.example/alternate.jpg',
      edition_code: 'OP-09',
      edition_name: 'Emperors in the New World',
    },
    {
      card_code: 'OP09-093-P',
      card_name: 'Marshall.D.Teach (093) (Parallel)',
      image_url: 'https://liga.example/manga.jpg',
      edition_code: 'OP-09',
      edition_name: 'Emperors in the New World',
    },
    {
      card_code: 'OP09-093-WP',
      card_name: 'Marshall.D.Teach (093) (Wanted Poster)',
      image_url: 'https://liga.example/wanted.jpg',
      edition_code: 'OP-09',
      edition_name: 'Emperors in the New World',
    },
  ]);

  assert.equal(merged.length, 3);
  assert.equal(merged[2].card_set_id, 'OP09-093-WP');
});

test('keeps same-named printings from different editions', () => {
  const merged = mergeCatalogCards(
    [
      {
        card_set_id: 'OP04-031',
        card_name: 'Donquixote Doflamingo (031) (Alternate Art)',
        card_image: 'https://api.example/original.jpg',
        set_id: 'OP-04',
        set_name: 'Kingdoms of Intrigue',
      },
    ],
    [
      {
        card_code: 'OP04-031-AA',
        card_name: 'Donquixote Doflamingo (Alternate Art)',
        image_url: 'https://liga.example/reprint.jpg',
        edition_code: 'PRB01',
        edition_name: 'Premium Booster -The Best-',
      },
    ],
  );

  assert.equal(merged.length, 2);
});

test('reads every public catalog page from Supabase', async () => {
  const requests = [];
  const rows = await fetchCatalogCards({
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
                card_code: `OP01-${String(index).padStart(3, '0')}`,
              }))
            : [{ card_code: 'ST31-001' }],
      };
    },
  });

  assert.equal(rows.length, 1001);
  assert.equal(requests.length, 2);
  assert.equal(requests[0].searchParams.get('image_url'), 'neq.');
  assert.equal(requests[1].searchParams.get('offset'), '1000');
});
