const assert = require('node:assert/strict');
const test = require('node:test');

const healthHandler = require('../api/health');
const {
  observeRequest,
  safeError,
} = require('../server/api-observability');

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
    end() {
      return this;
    },
  };
}

test('request observation adds a correlation id and structured completion log', () => {
  const messages = [];
  const originalLog = console.log;
  console.log = (message) => messages.push(JSON.parse(message));
  try {
    const res = responseDouble();
    observeRequest(
      {method: 'GET', headers: {'x-vercel-id': 'gru1::known-request'}},
      res,
      '/api/test',
    );
    res.status(204).end();

    assert.equal(res.headers['X-Request-ID'], 'gru1::known-request');
    assert.equal(messages[0].message, 'request_started');
    assert.equal(messages[1].message, 'request_completed');
    assert.equal(messages[1].status, 204);
    assert.equal(typeof messages[1].durationMs, 'number');
  } finally {
    console.log = originalLog;
  }
});

test('structured errors redact email and bearer credentials', () => {
  const value = safeError(
    new Error('user@example.com Bearer secret-access-token'),
  );
  assert.equal(value.includes('user@example.com'), false);
  assert.equal(value.includes('secret-access-token'), false);
});

test('health endpoint validates the public database dependency', async () => {
  const previousUrl = process.env.SUPABASE_URL;
  const previousKey = process.env.SUPABASE_ANON_KEY;
  const previousFetch = global.fetch;
  process.env.SUPABASE_URL = 'https://project.supabase.co';
  process.env.SUPABASE_ANON_KEY = 'public-anon-key';
  global.fetch = async () => ({ok: true, status: 200});

  try {
    const res = responseDouble();
    await healthHandler({method: 'GET', headers: {}}, res);
    assert.equal(res.statusCode, 200);
    assert.equal(res.body.status, 'ok');
    assert.equal(res.body.checks.database.status, 'ok');
    assert.equal(res.headers['Cache-Control'], 'no-store');
  } finally {
    global.fetch = previousFetch;
    if (previousUrl == null) delete process.env.SUPABASE_URL;
    else process.env.SUPABASE_URL = previousUrl;
    if (previousKey == null) delete process.env.SUPABASE_ANON_KEY;
    else process.env.SUPABASE_ANON_KEY = previousKey;
  }
});
