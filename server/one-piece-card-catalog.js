const PAGE_SIZE = 1000;

function normalizeText(value) {
  return String(value ?? '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ');
}

function baseCardCode(value) {
  const code = String(value ?? '').trim().toUpperCase();
  const match = /^(.+-\d{3})(?:-[A-Z0-9]+)?$/.exec(code);
  return match?.[1] ?? code;
}

function cardFingerprint(card) {
  return [
    String(card?.card_set_id ?? '').trim().toUpperCase(),
    normalizeText(card?.card_name),
    String(card?.card_image ?? '').trim(),
  ].join('|');
}

function toCatalogCard(row, cardsByCode) {
  const cardCode = String(row.card_code ?? '').trim().toUpperCase();
  const template =
    cardsByCode.get(cardCode) ?? cardsByCode.get(baseCardCode(cardCode)) ?? {};
  const editionCode = String(row.edition_code ?? '').trim().toUpperCase();
  const editionName = String(row.edition_name ?? '').trim();

  return {
    card_set_id: cardCode,
    card_name: String(row.card_name ?? cardCode).trim() || cardCode,
    card_image: String(row.image_url ?? '').trim(),
    set_id: editionCode,
    set_name:
      editionName || editionCode || String(template.set_name ?? '').trim(),
    rarity: String(row.rarity || template.rarity || '').trim(),
    card_color: String(row.color || template.card_color || '').trim(),
    card_type: String(row.card_type || template.card_type || '').trim(),
    sub_types: row.sub_types || template.sub_types || '',
    card_text: String(row.card_text || template.card_text || '').trim(),
    attribute: String(row.attribute || template.attribute || '').trim(),
    catalog_source: String(row.source ?? 'liga').trim() || 'liga',
  };
}

function mergeCatalogCards(cards, catalogRows) {
  const merged = Array.isArray(cards) ? [...cards] : [];
  const cardsByCode = new Map();
  const fingerprints = new Set();

  for (const card of merged) {
    const code = String(card?.card_set_id ?? '').trim().toUpperCase();
    if (code && !cardsByCode.has(code)) cardsByCode.set(code, card);
    fingerprints.add(cardFingerprint(card));
  }

  for (const row of catalogRows ?? []) {
    const catalogCard = toCatalogCard(row, cardsByCode);
    if (!catalogCard.card_set_id || !catalogCard.card_image) continue;

    const fingerprint = cardFingerprint(catalogCard);
    if (fingerprints.has(fingerprint)) continue;

    fingerprints.add(fingerprint);
    merged.push(catalogCard);
  }

  return merged;
}

async function fetchCatalogCards({
  fetchImpl = fetch,
  supabaseUrl,
  supabaseAnonKey,
}) {
  if (!supabaseUrl || !supabaseAnonKey) return [];

  const rows = [];
  for (let offset = 0; ; offset += PAGE_SIZE) {
    const url = new URL(
      '/rest/v1/one_piece_card_catalog',
      supabaseUrl.endsWith('/') ? supabaseUrl : `${supabaseUrl}/`,
    );
    url.searchParams.set(
      'select',
      'catalog_key,source,card_code,card_name,image_url,edition_code,' +
        'edition_name,rarity,color,card_type,sub_types,card_text,' +
        'attribute,resolved_at',
    );
    url.searchParams.set('image_url', 'neq.');
    url.searchParams.set('order', 'resolved_at.desc,catalog_key.asc');
    url.searchParams.set('limit', String(PAGE_SIZE));
    url.searchParams.set('offset', String(offset));

    const response = await fetchImpl(url, {
      headers: {
        Accept: 'application/json',
        apikey: supabaseAnonKey,
        Authorization: `Bearer ${supabaseAnonKey}`,
      },
    });
    if (!response.ok) {
      throw new Error(`Supabase card catalog returned ${response.status}`);
    }

    const page = await response.json();
    if (!Array.isArray(page)) {
      throw new Error('Unexpected Supabase card catalog payload');
    }

    rows.push(...page);
    if (page.length < PAGE_SIZE) break;
  }

  return rows;
}

module.exports = {
  PAGE_SIZE,
  baseCardCode,
  fetchCatalogCards,
  mergeCatalogCards,
  toCatalogCard,
};
