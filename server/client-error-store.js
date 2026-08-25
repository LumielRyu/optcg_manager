const {createClient} = require('@supabase/supabase-js');

let client;

function configured() {
  return Boolean(
    process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY,
  );
}

function serviceClient() {
  if (!client) {
    client = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY,
      {
        auth: {persistSession: false, autoRefreshToken: false},
        global: {headers: {'X-Client-Info': 'tcgbh-client-error-store'}},
      },
    );
  }
  return client;
}

async function persistClientError(payload, metadata = {}) {
  if (!configured()) return {stored: false, reason: 'not-configured'};

  const row = {
    reference_id: payload.referenceId,
    context: payload.context,
    error_message: payload.error,
    stack_trace: payload.stackTrace || null,
    path: payload.path || null,
    platform: payload.platform || null,
    diagnostics: payload.diagnostics || {},
    user_agent: clean(metadata.userAgent, 500) || null,
    request_id: clean(metadata.requestId, 120) || null,
    deployment_id: clean(process.env.VERCEL_DEPLOYMENT_ID, 180) || null,
    git_commit_sha: clean(process.env.VERCEL_GIT_COMMIT_SHA, 80) || null,
    received_at: payload.receivedAt,
  };

  const {error} = await serviceClient()
    .from('client_error_events')
    .upsert(row, {onConflict: 'reference_id', ignoreDuplicates: true});
  if (error) throw error;
  return {stored: true};
}

function clean(value, maximumLength) {
  return String(value || '')
    .replace(/[\u0000-\u001F\u007F]/g, ' ')
    .trim()
    .slice(0, maximumLength);
}

module.exports = {configured, persistClientError};
