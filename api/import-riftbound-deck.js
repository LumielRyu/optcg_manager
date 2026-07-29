const {
  applyApiHeaders,
  applyCorsHeaders,
  rejectNonJson,
  rejectRateLimited,
  rejectUntrustedOrigin,
} = require('../server/api-security');
const {observeRequest} = require('../server/api-observability');
const {
  extractPiltoverDeckId,
  fetchPiltoverDeck,
} = require('../server/riftbound-piltover-import');

module.exports = async (req, res) => {
  const observation = observeRequest(
    req,
    res,
    '/api/import-riftbound-deck',
  );
  applyApiHeaders(res);
  applyCorsHeaders(req, res);

  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') {
    return res.status(405).json({error: 'Method not allowed'});
  }
  if (rejectUntrustedOrigin(req, res) || rejectNonJson(req, res)) return;
  if (
    rejectRateLimited(req, res, {
      name: 'import-riftbound-deck',
      limit: 20,
      windowMs: 60 * 1000,
    })
  ) {
    return;
  }

  const deckId = extractPiltoverDeckId(req.body?.url);
  if (!deckId) {
    return res.status(400).json({
      error: 'Invalid Piltover Archive deck URL',
    });
  }

  try {
    const imported = await fetchPiltoverDeck(deckId);
    observation.event('piltover_deck_imported', {
      deckId,
      totalCards: imported.totalCards,
    });
    return res.status(200).json(imported);
  } catch (error) {
    observation.error(error, 'piltover_deck_import_failed');
    return res.status(502).json({
      error: 'Unable to import this Piltover Archive deck',
    });
  }
};
