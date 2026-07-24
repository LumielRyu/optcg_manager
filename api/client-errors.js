const MAX_BODY_BYTES = 12 * 1024;
const ALLOWED_CONTEXT = /^[a-zA-Z0-9_.:\-/ ]{1,120}$/;
const REFERENCE_ID = /^[A-Z0-9]{6,32}$/;
const {
  applyApiHeaders,
  applyCorsHeaders,
  rejectNonJson,
  rejectRateLimited,
  rejectUntrustedOrigin,
} = require('../server/api-security');
const {observeRequest, writeLog} = require('../server/api-observability');

module.exports = async (req, res) => {
  const observation = observeRequest(req, res, '/api/client-errors');
  applyApiHeaders(res);
  applyCorsHeaders(req, res);

  if (req.method === 'OPTIONS') {
    return res.status(204).end();
  }

  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({error: 'Method not allowed'});
  }
  if (rejectUntrustedOrigin(req, res) || rejectNonJson(req, res)) return;
  if (
    rejectRateLimited(req, res, {
      name: 'client-errors',
      limit: 20,
      windowMs: 60 * 1000,
    })
  ) return;

  const contentLength = Number(req.headers['content-length'] || 0);
  if (contentLength > MAX_BODY_BYTES) {
    return res.status(413).json({error: 'Payload too large'});
  }

  const payload = normalizePayload(req.body);
  if (!payload) {
    return res.status(400).json({error: 'Invalid error report'});
  }

  writeLog('error', 'client_error', {
    requestId: observation.requestId,
    ...payload,
  });
  return res.status(202).json({accepted: true, referenceId: payload.referenceId});
};

function normalizePayload(body) {
  let value = body;
  if (typeof body === 'string') {
    try {
      value = JSON.parse(body);
    } catch (_) {
      return null;
    }
  }

  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;

  const referenceId = clean(value.referenceId, 32);
  const context = clean(value.context, 120);
  const error = clean(value.error, 1200);
  if (!REFERENCE_ID.test(referenceId) || !ALLOWED_CONTEXT.test(context) || !error) {
    return null;
  }

  return {
    referenceId,
    context,
    error,
    stackTrace: clean(value.stackTrace, 5000),
    path: clean(value.path, 300),
    platform: clean(value.platform, 40),
    receivedAt: new Date().toISOString(),
  };
}

function clean(value, maximumLength) {
  return redact(String(value || ''))
    .replace(/[\u0000-\u001F\u007F]/g, ' ')
    .trim()
    .slice(0, maximumLength);
}

function redact(value) {
  return value
    .replace(/\bBearer\s+[A-Za-z0-9._~+\/-]+=*/gi, 'Bearer [redacted]')
    .replace(/\b[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\b/g, '[token]')
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[email]');
}
