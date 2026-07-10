const DEFAULT_ALLOWED_ORIGINS = new Set([
  'https://optcgbh.vercel.app',
  'https://optcgmanager.vercel.app',
  'https://optcgmanager-lumielryus-projects.vercel.app',
  'https://optcgmanager-lumielryu-lumielryus-projects.vercel.app',
]);

module.exports = async (req, res) => {
  setCorsHeaders(res, req);

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const text = stringValue(req.body?.text);
  if (!text) {
    return res.status(400).json({ error: 'Missing text' });
  }

  if (text.length > 6000) {
    return res.status(413).json({ error: 'Text is too long' });
  }

  try {
    const translatedText = await translateText(text);
    return res.status(200).json({ translatedText });
  } catch (error) {
    return res.status(502).json({
      error: 'Unable to translate card text',
      detail: error instanceof Error ? error.message : String(error),
    });
  }
};

async function translateText(text) {
  const url = new URL('https://translate.googleapis.com/translate_a/single');
  url.searchParams.set('client', 'gtx');
  url.searchParams.set('sl', 'en');
  url.searchParams.set('tl', 'pt');
  url.searchParams.set('dt', 't');
  url.searchParams.set('q', text);

  const response = await fetch(url, {
    headers: {
      Accept: 'application/json, text/plain, */*',
      'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
      'User-Agent': 'OPTCG BH/1.0 (+https://optcgbh.vercel.app)',
    },
  });

  if (!response.ok) {
    throw new Error(`Google Translate returned ${response.status}`);
  }

  const payload = await response.json();
  const translatedText = extractTranslatedText(payload);
  if (!translatedText) {
    throw new Error('Unexpected translation payload');
  }

  return translatedText;
}

function extractTranslatedText(payload) {
  if (!Array.isArray(payload) || !Array.isArray(payload[0])) return '';
  return payload[0]
    .map((item) => (Array.isArray(item) ? stringValue(item[0]) : ''))
    .join('')
    .trim();
}

function setCorsHeaders(res, req) {
  const origin = req?.headers?.origin || '';
  if (isAllowedOrigin(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Cache-Control', 's-maxage=86400, stale-while-revalidate=604800');
  res.setHeader('X-Content-Type-Options', 'nosniff');
}

function isAllowedOrigin(origin) {
  if (!origin) return false;
  if (DEFAULT_ALLOWED_ORIGINS.has(origin)) return true;
  if (/^https:\/\/optcgbh-[a-z0-9-]+-lumielryus-projects\.vercel\.app$/i.test(origin)) {
    return true;
  }
  return /^https:\/\/optcgmanager-[a-z0-9-]+-lumielryus-projects\.vercel\.app$/i.test(
    origin,
  );
}

function stringValue(value) {
  return value == null ? '' : String(value).trim();
}
