const assert = require('node:assert/strict');
const test = require('node:test');

const {
  buildPiltoverDeckText,
  extractPiltoverDeckId,
  fetchPiltoverDeck,
} = require('../server/riftbound-piltover-import');

const deckId = '99f9a2a9-b0fd-4399-bdfd-4327a030c6e3';

test('accepts only Piltover Archive deck URLs or a bare UUID', () => {
  assert.equal(
    extractPiltoverDeckId(
      `https://piltoverarchive.com/decks/view/${deckId}`,
    ),
    deckId,
  );
  assert.equal(extractPiltoverDeckId(deckId.toUpperCase()), deckId);
  assert.equal(
    extractPiltoverDeckId(`https://example.com/decks/view/${deckId}`),
    '',
  );
  assert.equal(
    extractPiltoverDeckId('https://piltoverarchive.com/decks/view/not-a-uuid'),
    '',
  );
});

test('converts the external deck response to the supported text format', () => {
  const imported = buildPiltoverDeckText(
    {id: deckId, name: 'Master Yi'},
    {
      breakdown: {
        legend: [{cardName: 'Master Yi, Wuju Bladesman', quantity: 1}],
        champions: [{cardName: 'Master Yi, Tempered', quantity: 1}],
        maindeck: [{cardName: 'Charm', quantity: 3}],
        battlefields: [{cardName: "Emperor's Dais", quantity: 1}],
        runes: [{cardName: 'Body Rune', quantity: 7}],
        sideboard: [{cardName: 'Challenge', quantity: 1}],
      },
    },
  );

  assert.equal(imported.deckName, 'Master Yi');
  assert.equal(imported.totalCards, 14);
  assert.match(imported.text, /Legend:\n1 Master Yi, Wuju Bladesman/);
  assert.match(imported.text, /MainDeck:\n3 Charm/);
  assert.match(imported.text, /Sideboard:\n1 Challenge/);
});

test('fetches only the fixed public Piltover endpoints', async () => {
  const urls = [];
  const imported = await fetchPiltoverDeck(deckId, {
    fetchImpl: async (url) => {
      urls.push(url);
      const payload = url.endsWith('/price')
        ? {
            breakdown: {
              legend: [{cardName: 'Annie, Fiery', quantity: 1}],
            },
          }
        : {id: deckId, name: 'Annie'};
      return {
        ok: true,
        status: 200,
        headers: {get: () => null},
        text: async () => JSON.stringify(payload),
      };
    },
  });

  assert.deepEqual(urls, [
    `https://piltoverarchive.com/api/external/v1/decks/${deckId}`,
    `https://piltoverarchive.com/api/external/v1/decks/${deckId}/price`,
  ]);
  assert.equal(imported.totalCards, 1);
});
