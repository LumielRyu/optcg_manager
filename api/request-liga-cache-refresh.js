const {
  applyApiHeaders,
  applyCorsHeaders,
  rejectNonJson,
  rejectRateLimited,
  rejectUntrustedOrigin,
} = require('../server/api-security');
const {observeRequest} = require('../server/api-observability');

module.exports = async (req, res) => {
  const observation = observeRequest(
    req,
    res,
    '/api/request-liga-cache-refresh',
  );
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
      name: 'request-liga-cache-refresh',
      limit: 10,
      windowMs: 10 * 60 * 1000,
    })
  ) return;

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
    observation.error(
      new Error(`GitHub workflow dispatch returned ${response.status}: ${detail}`),
      'workflow_dispatch_failed',
    );
    return res.status(502).json({
      error: 'Unable to dispatch Liga cache workflow',
    });
  }

  return res.status(202).json({ ok: true, cardCode });
};

function stringValue(value) {
  return value == null ? '' : String(value).trim();
}
