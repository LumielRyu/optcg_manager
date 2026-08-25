const assert = require('node:assert/strict');
const test = require('node:test');

const {
  applyApiHeaders,
  isAllowedOrigin,
  rejectNonJson,
  rejectRateLimited,
  rejectUntrustedOrigin,
  resetRateLimitsForTests,
} = require('../server/api-security');
const clientErrorsHandler = require('../api/client-errors');
const {normalizePayload} = clientErrorsHandler;

function responseDouble() {
  return {
    headers: {},
    statusCode: 200,
    body: null,
    setHeader(name, value) {
      this.headers[name] = value;
      return this;
    },
    status(value) {
      this.statusCode = value;
      return this;
    },
    json(value) {
      this.body = value;
      return this;
    },
  };
}

test('accepts production and preview origins, but rejects foreign origins', () => {
  assert.equal(isAllowedOrigin('https://tcgbh.vercel.app'), true);
  assert.equal(isAllowedOrigin('https://optcgbh.vercel.app'), true);
  assert.equal(
    isAllowedOrigin('https://tcgbh-example-lumielryus-projects.vercel.app'),
    true,
  );
  assert.equal(
    isAllowedOrigin('https://optcgbh-example-lumielryus-projects.vercel.app'),
    true,
  );
  assert.equal(isAllowedOrigin('https://example.com'), false);
});

test('rejects a cross-site request before work is performed', () => {
  const res = responseDouble();
  const rejected = rejectUntrustedOrigin(
    {headers: {origin: 'https://example.com'}},
    res,
  );
  assert.equal(rejected, true);
  assert.equal(res.statusCode, 403);
});

test('requires JSON for protected POST endpoints', () => {
  const res = responseDouble();
  assert.equal(
    rejectNonJson({headers: {'content-type': 'text/plain'}}, res),
    true,
  );
  assert.equal(res.statusCode, 415);
});

test('limits bursts and returns retry information', () => {
  resetRateLimitsForTests();
  const req = {headers: {'x-real-ip': '203.0.113.10'}};
  const first = responseDouble();
  const second = responseDouble();
  assert.equal(
    rejectRateLimited(req, first, {name: 'test', limit: 1, windowMs: 60000}),
    false,
  );
  assert.equal(
    rejectRateLimited(req, second, {name: 'test', limit: 1, windowMs: 60000}),
    true,
  );
  assert.equal(second.statusCode, 429);
  assert.ok(Number(second.headers['Retry-After']) > 0);
});

test('adds defensive API response headers', () => {
  const res = responseDouble();
  applyApiHeaders(res);
  assert.equal(res.headers['Cache-Control'], 'no-store');
  assert.equal(res.headers['X-Content-Type-Options'], 'nosniff');
  assert.equal(res.headers['Referrer-Policy'], 'no-referrer');
});

test('client error endpoint rejects foreign origins', async () => {
  const res = responseDouble();
  await clientErrorsHandler(
    {
      method: 'POST',
      headers: {
        origin: 'https://example.com',
        'content-type': 'application/json',
      },
      body: {},
    },
    res,
  );
  assert.equal(res.statusCode, 403);
  assert.deepEqual(res.body, {error: 'Origin not allowed'});
});

test('client error endpoint normalizes safe browser diagnostics', () => {
  const payload = normalizePayload({
    referenceId: 'WEBABC123',
    context: 'marketplace.load',
    error: 'Failed to fetch',
    diagnostics: {
      online: true,
      visibility: 'visible',
      viewport: '390x844',
      connection: '4g',
      ignored: 'not persisted',
    },
  });

  assert.deepEqual(payload.diagnostics, {
    online: true,
    visibility: 'visible',
    viewport: '390x844',
    connection: '4g',
  });
});
