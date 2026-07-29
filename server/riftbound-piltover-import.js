const PILTOVER_HOSTS = new Set([
  'piltoverarchive.com',
  'www.piltoverarchive.com',
]);

function extractPiltoverDeckId(value) {
  const raw = String(value || '').trim();
  if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(raw)) {
    return raw.toLowerCase();
  }

  let url;
  try {
    url = new URL(raw);
  } catch (_) {
    return '';
  }
  if (url.protocol !== 'https:' || !PILTOVER_HOSTS.has(url.hostname)) {
    return '';
  }
  const match = url.pathname.match(
    /^\/decks\/view\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/?$/i,
  );
  return match?.[1]?.toLowerCase() || '';
}

function buildPiltoverDeckText(deck, pricing) {
  const breakdown = pricing?.breakdown || {};
  const sections = [
    ['Legend', breakdown.legend],
    ['Champion', breakdown.champions],
    ['MainDeck', breakdown.maindeck],
    ['Battlefields', breakdown.battlefields],
    ['Runes', breakdown.runes],
    ['Sideboard', breakdown.sideboard],
  ];
  const output = [];
  let totalCards = 0;
  const sectionTotals = {};

  for (const [label, rawEntries] of sections) {
    const entries = Array.isArray(rawEntries) ? rawEntries : [];
    if (entries.length === 0) continue;
    output.push(`${label}:`);
    let sectionTotal = 0;
    for (const entry of entries) {
      const cardName = String(entry?.cardName || '').trim();
      const quantity = positiveInteger(entry?.quantity);
      if (!cardName || quantity <= 0) continue;
      output.push(`${quantity} ${cardName}`);
      sectionTotal += quantity;
    }
    if (sectionTotal === 0) {
      output.pop();
      continue;
    }
    sectionTotals[label] = sectionTotal;
    totalCards += sectionTotal;
    output.push('');
  }

  if (totalCards === 0) {
    throw new Error('Piltover deck did not contain importable cards');
  }

  return {
    deckId: String(deck?.id || '').trim(),
    deckName: String(deck?.name || 'Deck do Piltover Archive').trim(),
    text: output.join('\n').trim(),
    totalCards,
    sectionTotals,
    hasBench:
      Array.isArray(breakdown.bench) && breakdown.bench.length > 0,
  };
}

async function fetchPiltoverDeck(deckId, {fetchImpl = fetch} = {}) {
  const base = `https://piltoverarchive.com/api/external/v1/decks/${deckId}`;
  const headers = {
    Accept: 'application/json',
    'User-Agent': 'TCG-BH/1.0 (+https://tcgbh.vercel.app)',
  };
  const [deckResponse, priceResponse] = await Promise.all([
    fetchImpl(base, {
      headers,
      signal: AbortSignal.timeout(8000),
    }),
    fetchImpl(`${base}/price`, {
      headers,
      signal: AbortSignal.timeout(8000),
    }),
  ]);
  if (!deckResponse.ok || !priceResponse.ok) {
    throw new Error(
      `Piltover Archive returned ${deckResponse.status}/${priceResponse.status}`,
    );
  }
  const [deck, pricing] = await Promise.all([
    readJsonResponse(deckResponse),
    readJsonResponse(priceResponse),
  ]);
  return buildPiltoverDeckText(deck, pricing);
}

async function readJsonResponse(response) {
  const contentLength = Number(response.headers?.get?.('content-length') || 0);
  if (contentLength > 1_000_000) {
    throw new Error('Piltover Archive response is too large');
  }
  const text = await response.text();
  if (text.length > 1_000_000) {
    throw new Error('Piltover Archive response is too large');
  }
  return JSON.parse(text);
}

function positiveInteger(value) {
  const quantity = Number.parseInt(String(value ?? ''), 10);
  return Number.isInteger(quantity) && quantity > 0 ? quantity : 0;
}

module.exports = {
  buildPiltoverDeckText,
  extractPiltoverDeckId,
  fetchPiltoverDeck,
};
