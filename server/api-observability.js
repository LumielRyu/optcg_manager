const {randomUUID} = require('node:crypto');

function observeRequest(req, res, route) {
  const startedAt = Date.now();
  const requestId = requestIdentifier(req);
  let completed = false;

  res.setHeader('X-Request-ID', requestId);
  writeLog('info', 'request_started', {
    route,
    method: String(req?.method || 'UNKNOWN'),
    requestId,
  });

  const complete = () => {
    if (completed) return;
    completed = true;
    writeLog('info', 'request_completed', {
      route,
      method: String(req?.method || 'UNKNOWN'),
      requestId,
      status: Number(res.statusCode || 200),
      durationMs: Date.now() - startedAt,
    });
  };

  wrapCompletion(res, 'json', complete);
  wrapCompletion(res, 'end', complete);
  wrapCompletion(res, 'send', complete);

  return {
    requestId,
    error(error, message = 'request_failed') {
      writeLog('error', message, {
        route,
        method: String(req?.method || 'UNKNOWN'),
        requestId,
        durationMs: Date.now() - startedAt,
        error: safeError(error),
      });
    },
    event(message, fields = {}) {
      writeLog('info', message, {route, requestId, ...fields});
    },
  };
}

function wrapCompletion(res, method, complete) {
  const original = res?.[method];
  if (typeof original !== 'function') return;
  res[method] = function observedResponseMethod(...args) {
    complete();
    return original.apply(this, args);
  };
}

function requestIdentifier(req) {
  const candidate = String(
    req?.headers?.['x-vercel-id'] || req?.headers?.['x-request-id'] || '',
  )
    .replace(/[^a-zA-Z0-9_.:\-]/g, '')
    .slice(0, 120);
  return candidate || randomUUID();
}

function safeError(error) {
  const value = error instanceof Error ? error.message : String(error || '');
  return value
    .replace(/\bBearer\s+[A-Za-z0-9._~+\/-]+=*/gi, 'Bearer [redacted]')
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[email]')
    .slice(0, 800);
}

function writeLog(level, message, fields = {}) {
  const payload = JSON.stringify({
    level,
    message,
    timestamp: new Date().toISOString(),
    ...fields,
  });
  if (level === 'error') {
    console.error(payload);
  } else {
    console.log(payload);
  }
}

module.exports = {observeRequest, safeError, writeLog};
