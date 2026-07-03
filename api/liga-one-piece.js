const LIGA_BASE_URL = 'https://www.ligaonepiece.com.br/';
const ALLOWED_HOSTS = new Set(['www.ligaonepiece.com.br', 'ligaonepiece.com.br']);
const DEFAULT_ALLOWED_ORIGINS = new Set([
  'https://optcgmanager.vercel.app',
  'https://optcgmanager-lumielryus-projects.vercel.app',
  'https://optcgmanager-lumielryu-lumielryus-projects.vercel.app',
]);

module.exports = async (req, res) => {
  setCorsHeaders(res, req);

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

    const requestedCardName = stringValue(req.query.cardName);
    const edition = editions[0] || {};
    const preferFoil = wantsFoilPrice(requestedCardName);
    const price = selectPriceMap(edition.price, preferFoil);
    const desiredExtra = preferFoil ? 2 : 0;
    const listings = stock
      .filter((item) => {
        if (item.extras == null) return true;
        return parseInteger(item.extras) === desiredExtra;
      })
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
    const publicMessage =
      statusCode >= 500 ? 'Unable to fetch LigaOnePiece data' : error.message;

    return res.status(statusCode).json({
      error: publicMessage,
    });
  }
};

function setCorsHeaders(res, req) {
  const origin = req?.headers?.origin || '';
  const configuredOrigins = String(process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  const allowedOrigins = new Set([
    ...DEFAULT_ALLOWED_ORIGINS,
    ...configuredOrigins,
  ]);
  if (isAllowedOrigin(origin, allowedOrigins)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Cache-Control', 's-maxage=900, stale-while-revalidate=3600');
  res.setHeader('X-Content-Type-Options', 'nosniff');
}

function isAllowedOrigin(origin, allowedOrigins) {
  if (allowedOrigins.has(origin)) return true;
  return /^https:\/\/optcgmanager-[a-z0-9-]+-lumielryus-projects\.vercel\.app$/i.test(
    origin,
  );
}

async function resolveSource(query) {
  const rawUrl = stringValue(query.url);
  const candidates = rawUrl
    ? [validateLigaUrl(rawUrl)]
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
      headers: browserLikeHeaders(sourceUrl),
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

function browserLikeHeaders(sourceUrl) {
  return {
    Accept:
      'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
    'Cache-Control': 'no-cache',
    Pragma: 'no-cache',
    Referer: LIGA_BASE_URL,
    Origin: 'https://www.ligaonepiece.com.br',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': sameLigaOrigin(sourceUrl) ? 'same-origin' : 'none',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  };
}

function sameLigaOrigin(sourceUrl) {
  try {
    return new URL(sourceUrl).origin === new URL(LIGA_BASE_URL).origin;
  } catch (_) {
    return false;
  }
}

function validateLigaUrl(rawUrl) {
  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch (_) {
    const error = new Error('Invalid url query param');
    error.statusCode = 400;
    throw error;
  }

  if (parsed.protocol !== 'https:' || !ALLOWED_HOSTS.has(parsed.hostname)) {
    const error = new Error('URL host is not allowed');
    error.statusCode = 400;
    throw error;
  }

  return parsed.toString();
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
  const edition = inferEdition(cardCode);
  const descriptors = [];

  const pushDescriptor = (value) => {
    const normalized = stringValue(value);
    if (!normalized || descriptors.includes(normalized)) return;
    descriptors.push(normalized);
  };

  for (const { label, suffix } of specialSuffixesForName(cardName)) {
    pushDescriptor(`${cleanName} (${label}) (${cardCode}-${suffix})`);
  }

  pushDescriptor(`${cleanName}${isReprint ? ' (Reprint)' : ''} (${ligaCode})`);

  if (numberLabel) {
    pushDescriptor(
      `${cleanName} (${numberLabel})${isReprint ? ' (Reprint)' : ''} (${ligaCode})`,
    );
  }

  pushDescriptor(`${normalizedOriginalName} (${ligaCode})`);
  pushDescriptor(normalizedOriginalName);

  const cardUrls = [];
  const searchUrls = [];

  for (const descriptor of descriptors) {
    if (edition) {
      const cardUrl = new URL(LIGA_BASE_URL);
      cardUrl.searchParams.set('view', 'cards/card');
      cardUrl.searchParams.set('card', descriptor);
      cardUrl.searchParams.set('ed', edition);
      cardUrl.searchParams.set('num', cardCode);
      cardUrls.push(cardUrl.toString());
    }

    const searchUrl = new URL(LIGA_BASE_URL);
    searchUrl.searchParams.set('view', 'cards/search');
    searchUrl.searchParams.set('card', descriptor);
    searchUrl.searchParams.set('tipo', '1');
    searchUrls.push(searchUrl.toString());
  }

  return [...new Set([...cardUrls, ...searchUrls])];
}

function inferEdition(cardCode) {
  const match = stringValue(cardCode).match(/^([A-Z]{1,4})(\d{2})-\d{3}/);
  if (!match) return '';
  const [, prefix, number] = match;
  return prefix === 'EB' ? `${prefix}${number}` : `${prefix}-${number}`;
}

function specialSuffixesForName(cardName) {
  const normalized = stringValue(cardName)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
  const tokens = new Set(normalized.split(/\s+/).filter(Boolean));
  const suffixes = [];
  if (tokens.has('sp')) {
    suffixes.push({ label: 'SP', suffix: 'SP' });
  }
  return suffixes;
}

function cleanCardName(cardName) {
  return cardName
    .trim()
    .replace(/\s*-\s*[A-Z]{1,4}\d{2}-\d{3}(?:-[A-Z0-9]+)?/g, '')
    .replace(/\(Reprint\)/g, '')
    .replace(
      /\s*\((?:Alternate Art|Alt Art|SP|Parallel|Manga|Special|Treasure|Wanted)\)/gi,
      '',
    )
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

function wantsFoilPrice(cardName) {
  const normalized = stringValue(cardName)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
  if (!normalized) return false;
  const tokens = new Set(normalized.split(/\s+/));
  return (
    tokens.has('sp') ||
    normalized.includes('alternate art') ||
    normalized.includes('alt art') ||
    normalized.includes('parallel') ||
    normalized.includes('manga') ||
    normalized.includes('special') ||
    normalized.includes('treasure') ||
    normalized.includes('wanted')
  );
}

function selectPriceMap(rawPrice, preferFoil) {
  if (Array.isArray(rawPrice)) {
    if (!rawPrice.length) return {};
    const foilIndex = rawPrice.length > 2 ? 2 : 1;
    const index = preferFoil ? foilIndex : 0;
    return mapValue(rawPrice[index] || rawPrice[0]);
  }

  const price = mapValue(rawPrice);

  if (preferFoil) {
    const foilPrice = mapValue(price['2'] || price['1']);
    if (Object.keys(foilPrice).length) return foilPrice;
  }

  const normalPrice = mapValue(price['0']);
  if (Object.keys(normalPrice).length) return normalPrice;

  const firstNestedPrice = Object.values(price).find(
    (value) => value && typeof value === 'object',
  );
  return mapValue(firstNestedPrice || price);
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
