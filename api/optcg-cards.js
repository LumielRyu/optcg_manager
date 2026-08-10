const endpoints = [
  'https://www.optcgapi.com/api/allSetCards/?format=json',
  'https://www.optcgapi.com/api/allSTCards/?format=json',
  'https://www.optcgapi.com/api/allPromos/?format=json',
];

const jsonHeaders = {
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control':
    'public, max-age=300, s-maxage=900, stale-while-revalidate=86400',
};

import observability from '../server/api-observability.js';
import cardCatalog from '../server/one-piece-card-catalog.js';
import promotionalCatalog from '../server/one-piece-promotional-cards.js';

const { observeRequest } = observability;
const { fetchCatalogCards, mergeCatalogCards } = cardCatalog;
const { fetchPromotionalCards, mergePromotionalCards } = promotionalCatalog;

export default async function handler(request, response) {
  const observation = observeRequest(request, response, '/api/optcg-cards');
  if (request.method === 'OPTIONS') {
    response.setHeader('Allow', 'GET, OPTIONS');
    response.status(204).end();
    return;
  }

  if (request.method !== 'GET') {
    response.setHeader('Allow', 'GET, OPTIONS');
    response.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const payloads = await Promise.all(
      endpoints.map(async (url) => {
        const upstream = await fetch(url, {
          headers: {
            Accept: 'application/json',
            'User-Agent': 'TCG BH/1.0 (+https://tcgbh.vercel.app)',
          },
        });

        if (!upstream.ok) {
          throw new Error(`OPTCG API returned ${upstream.status} for ${url}`);
        }

        const payload = await upstream.json();
        if (!Array.isArray(payload)) {
          throw new Error(`Unexpected OPTCG API payload for ${url}`);
        }

        return payload;
      }),
    );

    const cards = payloads.flat();
    let mergedCards = cards;
    const catalogStartedAt = Date.now();
    const [promotionalResult, catalogResult] = await Promise.allSettled([
      fetchPromotionalCards({
        supabaseUrl: process.env.SUPABASE_URL,
        supabaseAnonKey: process.env.SUPABASE_ANON_KEY,
      }),
      fetchCatalogCards({
        supabaseUrl: process.env.SUPABASE_URL,
        supabaseAnonKey: process.env.SUPABASE_ANON_KEY,
      }),
    ]);

    if (promotionalResult.status === 'fulfilled') {
      mergedCards = mergePromotionalCards(
        mergedCards,
        promotionalResult.value,
      );
    } else {
      observation.error(
        promotionalResult.reason,
        'optcg_promotional_catalog_fetch_failed',
      );
    }

    if (catalogResult.status === 'fulfilled') {
      mergedCards = mergeCatalogCards(mergedCards, catalogResult.value);
    } else {
      observation.error(
        catalogResult.reason,
        'optcg_card_catalog_fetch_failed',
      );
    }

    console.log(
      JSON.stringify({
        level: 'info',
        message: 'optcg_catalog_loaded',
        durationMs: Date.now() - catalogStartedAt,
        upstreamCards: cards.length,
        promotionalCards:
          promotionalResult.status === 'fulfilled'
            ? promotionalResult.value.length
            : null,
        catalogCards:
          catalogResult.status === 'fulfilled'
            ? catalogResult.value.length
            : null,
        mergedCards: mergedCards.length,
      }),
    );

    response.setHeader('Cache-Control', jsonHeaders['Cache-Control']);
    response.status(200).json(mergedCards);
  } catch (error) {
    observation.error(error, 'optcg_cards_fetch_failed');
    response
      .status(502)
      .setHeader('Content-Type', jsonHeaders['Content-Type'])
      .json({
        error: 'Unable to fetch OPTCG cards',
        detail: error instanceof Error ? error.message : String(error),
      });
  }
}
