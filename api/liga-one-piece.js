const LIGA_BASE_URL = 'https://www.ligaonepiece.com.br/';

module.exports = async (req, res) => {
  setCorsHeaders(res);

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { sourceUrl, html } = await resolveSource(req.query);
    const editions = decodeInlineJsonList(html, 'cards_editions');
    const stock = decodeInlineJsonList(html, 'cards_stock');
    const stores = decodeInlineJsonMap(html, 'cards_stores');

    const edition = editions[0] || {};
    const price = mapValue(edition.price)?.['0'] || {};
    const listings = stock
      .map((item) => ({
        id: parseInteger(item.id),
        quantity: parseInteger(item.quant),
        price: parseMoney(item.precoFinal),
        storeId: parseInteger(item.lj_id),
        state: stringValue(item.lj_uf),
      }))
      .filter((item) => item.price !== null)
      .sort((a, b) => a.price - b.price);

    const lowestListing = listings[0] || null;
    const lowestStore =
      lowestListing == null
        ? null
        : normalizeStore(stores[String(lowestListing.storeId)] || {});

    return res.status(200).json({
      sourceUrl,
      cardName: extractCardName(html) || stringValue(edition.num),
      cardCode: stringValue(edition.num),
      editionCode: stringValue(edition.code),
      imageUrl: normalizeAssetUrl(stringValue(edition.img)),
      minimumPrice: parseMoney(price.p),
      averagePrice: parseMoney(price.m),
      maximumPrice: parseMoney(price.g),
      listingCount: listings.length,
      lowestListing,
      lowestStore,
      historyEndpointRequiresLogin: true,
    });
  } catch (error) {
    const statusCode =
      typeof error?.statusCode === 'number' ? error.statusCode : 500;

    return res.status(statusCode).json({
      error: error instanceof Error ? error.message : String(error),
      sourceUrl: error?.sourceUrl || null,
    });
  }
};

function setCorsHeaders(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Cache-Control', 's-maxage=900, stale-while-revalidate=3600');
}

async function resolveSource(query) {
  const rawUrl = stringValue(query.url);
  const candidates = rawUrl
    ? [rawUrl]
    : buildCandidateUrls(
        stringValue(query.cardName),
        stringValue(query.cardCode).toUpperCase(),
      );

  if (!candidates.length) {
    const error = new Error('Missing url or cardName/cardCode query params');
    error.statusCode = 400;
    throw error;
  }

  let lastStatus = 500;
  let lastUrl = candidates[0];

  for (const sourceUrl of candidates) {
    lastUrl = sourceUrl;

    const response = await fetch(sourceUrl, {
      headers: {
        Accept:
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'User-Agent': 'Mozilla/5.0 OPTCG-Manager Proxy',
      },
    });

    lastStatus = response.status;
    if (!response.ok) {
      continue;
    }

    const html = await response.text();
    if (decodeInlineJsonList(html, 'cards_editions').length) {
      return { sourceUrl, html };
    }
  }

  const error = new Error('cards_editions not found in source page');
  error.statusCode = lastStatus === 200 ? 422 : lastStatus;
  error.sourceUrl = lastUrl;
  throw error;
}

function buildCandidateUrls(cardName, cardCode) {
  const cleanName = cleanCardName(cardName);
  const normalizedOriginalName = cardName.trim().replace(/\s+/g, ' ');
  const isReprint =
    cardName.toLowerCase().includes('reprint') || cardCode.endsWith('-RE');
  const ligaCode = isReprint && !cardCode.endsWith('-RE')
    ? `${cardCode}-RE`
    : cardCode;
  const numberMatch = ligaCode.match(/-(\d{3})/);
  const numberLabel = numberMatch ? numberMatch[1] : '';
  const descriptors = [];

  const pushDescriptor = (value) => {
    const normalized = stringValue(value);
    if (!normalized || descriptors.includes(normalized)) return;
    descriptors.push(normalized);
  };

  pushDescriptor(`${cleanName}${isReprint ? ' (Reprint)' : ''} (${ligaCode})`);

  if (numberLabel) {
    pushDescriptor(
      `${cleanName} (${numberLabel})${isReprint ? ' (Reprint)' : ''} (${ligaCode})`,
    );
  }

  pushDescriptor(`${normalizedOriginalName} (${ligaCode})`);
  pushDescriptor(normalizedOriginalName);

  return descriptors.map((descriptor) => {
    const url = new URL(LIGA_BASE_URL);
    url.searchParams.set('view', 'cards/card');
    url.searchParams.set('card', descriptor);
    url.searchParams.set('tipo', '1');
    return url.toString();
  });
}

function cleanCardName(cardName) {
  return cardName
    .trim()
    .replace(/\s*-\s*[A-Z]{1,4}\d{2}-\d{3}(?:-[A-Z0-9]+)?/g, '')
    .replace(/\(Reprint\)/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function decodeInlineJsonList(html, variableName) {
  const raw = extractInlineAssignment(html, variableName);
  if (!raw) return [];
  const decoded = JSON.parse(raw);
  return Array.isArray(decoded) ? decoded : [];
}

function decodeInlineJsonMap(html, variableName) {
  const raw = extractInlineAssignment(html, variableName);
  if (!raw) return {};
  const decoded = JSON.parse(raw);
  return decoded && typeof decoded === 'object' ? decoded : {};
}

function extractInlineAssignment(html, variableName) {
  const escapedName = variableName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const regex = new RegExp(`${escapedName}\\s*=\\s*([\\[{][\\s\\S]*?[\\]}]);`);
  const match = html.match(regex);
  return match ? match[1] : null;
}

function extractCardName(html) {
  const match = html.match(/<div class="item-name">\s*([^<]+)\s*<\/div>/);
  return match ? match[1].trim() : '';
}

function normalizeStore(raw) {
  return {
    name: stringValue(raw.lj_name),
    city: stringValue(raw.lj_cidade),
    state: stringValue(raw.lj_uf),
    phone: stringValue(raw.lj_tel),
  };
}

function normalizeAssetUrl(value) {
  if (!value) return '';
  return value.startsWith('//') ? `https:${value}` : value;
}

function parseMoney(value) {
  const raw = stringValue(value);
  if (!raw) return null;
  const normalized = raw.includes(',')
    ? raw.replace(/\./g, '').replace(',', '.')
    : raw;
  const parsed = Number(normalized);
  return Number.isNaN(parsed) ? null : parsed;
}

function parseInteger(value) {
  const parsed = parseInt(stringValue(value), 10);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function stringValue(value) {
  return value == null ? '' : String(value).trim();
}

function mapValue(value) {
  return value && typeof value === 'object' ? value : {};
}
