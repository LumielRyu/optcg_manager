const {applyApiHeaders} = require('../server/api-security');
const {observeRequest} = require('../server/api-observability');

module.exports = async (req, res) => {
  const observation = observeRequest(req, res, '/api/health');
  applyApiHeaders(res);

  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({status: 'error'});
  }

  const supabaseUrl = String(process.env.SUPABASE_URL || '').replace(/\/$/, '');
  const supabaseAnonKey = String(process.env.SUPABASE_ANON_KEY || '');
  const checks = {
    function: {status: 'ok'},
    configuration: {
      status: supabaseUrl && supabaseAnonKey ? 'ok' : 'error',
    },
    database: {status: 'pending'},
  };

  if (checks.configuration.status === 'ok') {
    const startedAt = Date.now();
    try {
      const response = await fetch(
        `${supabaseUrl}/rest/v1/pokemon_tournament_reports?select=id&limit=1`,
        {
          headers: {
            apikey: supabaseAnonKey,
            Authorization: `Bearer ${supabaseAnonKey}`,
            Accept: 'application/json',
          },
          signal: AbortSignal.timeout(5000),
        },
      );
      checks.database = {
        status: response.ok ? 'ok' : 'error',
        latencyMs: Date.now() - startedAt,
      };
      if (!response.ok) {
        observation.error(
          new Error(`Supabase health query returned ${response.status}`),
          'dependency_check_failed',
        );
      }
    } catch (error) {
      checks.database = {
        status: 'error',
        latencyMs: Date.now() - startedAt,
      };
      observation.error(error, 'dependency_check_failed');
    }
  } else {
    checks.database = {status: 'skipped'};
    observation.error(new Error('Public Supabase configuration is missing'));
  }

  const healthy = Object.values(checks).every(
    (check) => check.status === 'ok',
  );
  return res.status(healthy ? 200 : 503).json({
    status: healthy ? 'ok' : 'degraded',
    timestamp: new Date().toISOString(),
    region: process.env.VERCEL_REGION || 'local',
    release: process.env.VERCEL_GIT_COMMIT_SHA?.slice(0, 12) || 'local',
    checks,
  });
};
