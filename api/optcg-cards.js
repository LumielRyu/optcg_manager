const endpoints = [
  'https://www.optcgapi.com/api/allSetCards/?format=json',
  'https://www.optcgapi.com/api/allSTCards/?format=json',
  'https://www.optcgapi.com/api/allPromos/?format=json',
];

const jsonHeaders = {
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 's-maxage=21600, stale-while-revalidate=86400',
};

export default async function handler(request, response) {
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
            'User-Agent': 'OPTCG BH/1.0 (+https://optcgbh.vercel.app)',
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

    response.setHeader('Cache-Control', jsonHeaders['Cache-Control']);
    response.status(200).json(payloads.flat());
  } catch (error) {
    response
      .status(502)
      .setHeader('Content-Type', jsonHeaders['Content-Type'])
      .json({
        error: 'Unable to fetch OPTCG cards',
        detail: error instanceof Error ? error.message : String(error),
      });
  }
}
