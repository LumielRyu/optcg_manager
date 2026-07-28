const DEFAULT_ALLOWED_ORIGINS = new Set([
  'https://tcgbh.vercel.app',
  'https://optcgbh.vercel.app',
  'https://optcgmanager.vercel.app',
  'https://optcgmanager-lumielryus-projects.vercel.app',
  'https://optcgmanager-lumielryu-lumielryus-projects.vercel.app',
]);

const buckets = new Map();

function allowedOrigins() {
  const configured = String(process.env.APP_ALLOWED_ORIGINS || '')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  return new Set([...DEFAULT_ALLOWED_ORIGINS, ...configured]);
}

function isAllowedOrigin(origin) {
  if (!origin) return true;
  if (allowedOrigins().has(origin)) return true;
  if (/^https:\/\/optcgbh-[a-z0-9-]+-lumielryus-projects\.vercel\.app$/i.test(origin)) {
    return true;
  }
  if (/^https:\/\/tcgbh-[a-z0-9-]+-lumielryus-projects\.vercel\.app$/i.test(origin)) {
    return true;
  }
  return /^https:\/\/optcgmanager-[a-z0-9-]+-lumielryus-projects\.vercel\.app$/i.test(
    origin,
  );
}

function applyApiHeaders(res, {cacheControl = 'no-store'} = {}) {
  res.setHeader('Cache-Control', cacheControl);
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('X-Permitted-Cross-Domain-Policies', 'none');
}

function applyCorsHeaders(req, res, methods = 'POST,OPTIONS') {
  const origin = String(req?.headers?.origin || '');
  if (origin && isAllowedOrigin(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
  }
  res.setHeader('Access-Control-Allow-Methods', methods);
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

function rejectUntrustedOrigin(req, res) {
  const origin = String(req?.headers?.origin || '');
  if (isAllowedOrigin(origin)) return false;
  res.status(403).json({error: 'Origin not allowed'});
  return true;
}

function rejectNonJson(req, res) {
  const contentType = String(req?.headers?.['content-type'] || '').toLowerCase();
  if (contentType.startsWith('application/json')) return false;
  res.status(415).json({error: 'Content-Type must be application/json'});
  return true;
}

function rejectRateLimited(req, res, {name, limit, windowMs}) {
  const now = Date.now();
  const address = clientAddress(req);
  const key = `${name}:${address}`;
  let bucket = buckets.get(key);

  if (!bucket || bucket.resetAt <= now) {
    bucket = {count: 0, resetAt: now + windowMs};
  }
  bucket.count += 1;
  buckets.set(key, bucket);

  const remaining = Math.max(0, limit - bucket.count);
  const resetSeconds = Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));
  res.setHeader('RateLimit-Limit', String(limit));
  res.setHeader('RateLimit-Remaining', String(remaining));
  res.setHeader('RateLimit-Reset', String(resetSeconds));

  if (buckets.size > 5000) {
    for (const [candidateKey, candidate] of buckets) {
      if (candidate.resetAt <= now) buckets.delete(candidateKey);
    }
  }

  if (bucket.count <= limit) return false;
  res.setHeader('Retry-After', String(resetSeconds));
  res.status(429).json({error: 'Too many requests'});
  return true;
}

function clientAddress(req) {
  const realIp = String(req?.headers?.['x-real-ip'] || '').trim();
  if (realIp) return realIp.slice(0, 80);
  const forwarded = String(req?.headers?.['x-forwarded-for'] || '')
    .split(',')[0]
    .trim();
  return (forwarded || 'unknown').slice(0, 80);
}

function resetRateLimitsForTests() {
  buckets.clear();
}

module.exports = {
  applyApiHeaders,
  applyCorsHeaders,
  isAllowedOrigin,
  rejectNonJson,
  rejectRateLimited,
  rejectUntrustedOrigin,
  resetRateLimitsForTests,
};
