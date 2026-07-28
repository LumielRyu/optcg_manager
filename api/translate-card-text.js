const {
  applyApiHeaders,
  applyCorsHeaders,
  rejectNonJson,
  rejectRateLimited,
  rejectUntrustedOrigin,
} = require('../server/api-security');
const {observeRequest} = require('../server/api-observability');

module.exports = async (req, res) => {
  const observation = observeRequest(req, res, '/api/translate-card-text');
  applyApiHeaders(res);
  applyCorsHeaders(req, res);

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  if (rejectUntrustedOrigin(req, res) || rejectNonJson(req, res)) return;
  if (
    rejectRateLimited(req, res, {
      name: 'translate-card-text',
      limit: 30,
      windowMs: 60 * 1000,
    })
  ) return;

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
    observation.error(error, 'translation_failed');
    return res.status(502).json({
      error: 'Unable to translate card text',
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
      'User-Agent': 'TCG BH/1.0 (+https://optcgbh.vercel.app)',
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

function stringValue(value) {
  return value == null ? '' : String(value).trim();
}
