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

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const token = process.env.GITHUB_ACTIONS_TOKEN || '';
  if (!token) {
    return res.status(503).json({ error: 'GitHub dispatch token is not configured' });
  }

  const cardCode = stringValue(req.body?.cardCode).toUpperCase();
  const cardName = stringValue(req.body?.cardName);

  if (!/^[A-Z]{1,4}\d{2}-\d{3}(?:-[A-Z0-9]+)?$/.test(cardCode)) {
    return res.status(400).json({ error: 'Invalid cardCode' });
  }

  const owner = process.env.GITHUB_REPOSITORY_OWNER || 'LumielRyu';
  const repo = process.env.GITHUB_REPOSITORY_NAME || 'optcg_manager';
  const ref = process.env.GITHUB_WORKFLOW_REF || 'main';
  const workflowId = 'update-liga-price-cache.yml';
  const endpoint = `https://api.github.com/repos/${owner}/${repo}/actions/workflows/${workflowId}/dispatches`;

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'User-Agent': 'optcg-manager',
      'X-GitHub-Api-Version': '2022-11-28',
    },
    body: JSON.stringify({
      ref,
      inputs: {
        card_code: cardCode,
        card_name: cardName || cardCode,
      },
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    return res.status(502).json({
      error: 'Unable to dispatch Liga cache workflow',
      status: response.status,
      detail,
    });
  }

  return res.status(202).json({ ok: true, cardCode });
};

function setCorsHeaders(res, req) {
  const origin = req?.headers?.origin || '';
  if (isAllowedOrigin(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', 'POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Cache-Control', 'no-store');
}

function isAllowedOrigin(origin) {
  if (DEFAULT_ALLOWED_ORIGINS.has(origin)) return true;
  return /^https:\/\/optcgmanager-[a-z0-9-]+-lumielryus-projects\.vercel\.app$/i.test(
    origin,
  );
}

function stringValue(value) {
  return value == null ? '' : String(value).trim();
}
