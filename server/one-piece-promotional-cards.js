const PROMOTIONAL_EDITION = 'PC-01';
const PROMOTIONAL_SET_NAME = 'Promotion Cards (PC-01)';
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

function toPromotionalCard(row, cardsByCode) {
  const cardCode = String(row.card_code ?? '').trim().toUpperCase();
  const template =
    cardsByCode.get(cardCode) ?? cardsByCode.get(baseCardCode(cardCode)) ?? {};

  return {
    card_set_id: cardCode,
    card_name: String(row.card_name ?? cardCode).trim() || cardCode,
    card_image: String(row.image_url ?? '').trim(),
    set_id: 'P',
    set_name: PROMOTIONAL_SET_NAME,
    rarity: String(template.rarity ?? 'Promo').trim() || 'Promo',
    card_color: String(template.card_color ?? '').trim(),
    card_type: String(template.card_type ?? '').trim(),
    sub_types: template.sub_types ?? '',
    card_text: String(template.card_text ?? '').trim(),
    attribute: String(template.attribute ?? '').trim(),
  };
}

function mergePromotionalCards(cards, promotionalRows) {
  const merged = Array.isArray(cards) ? [...cards] : [];
  const cardsByCode = new Map();
  const fingerprints = new Set();

  for (const card of merged) {
    const code = String(card?.card_set_id ?? '').trim().toUpperCase();
    if (code && !cardsByCode.has(code)) cardsByCode.set(code, card);
    fingerprints.add(
      `${code}|${normalizeText(card?.card_name)}|${String(
        card?.card_image ?? '',
      ).trim()}`,
    );
  }

  for (const row of promotionalRows ?? []) {
    const promotionalCard = toPromotionalCard(row, cardsByCode);
    if (!promotionalCard.card_set_id || !promotionalCard.card_image) continue;

    const existingVariantIndex = merged.findIndex(
      (card) =>
        baseCardCode(card?.card_set_id) ===
          baseCardCode(promotionalCard.card_set_id) &&
        normalizeText(card?.card_name) ===
          normalizeText(promotionalCard.card_name),
    );
    if (existingVariantIndex >= 0) {
      const canonicalCard = {
        ...merged[existingVariantIndex],
        ...promotionalCard,
      };
      merged[existingVariantIndex] = canonicalCard;
      cardsByCode.set(promotionalCard.card_set_id, canonicalCard);
      continue;
    }

    const fingerprint =
      `${promotionalCard.card_set_id}|${normalizeText(
        promotionalCard.card_name,
      )}|${promotionalCard.card_image}`;
    if (fingerprints.has(fingerprint)) continue;
    fingerprints.add(fingerprint);
    merged.push(promotionalCard);
  }

  return merged;
}

async function fetchPromotionalCards({
  fetchImpl = fetch,
  supabaseUrl,
  supabaseAnonKey,
}) {
  if (!supabaseUrl || !supabaseAnonKey) return [];

  const rows = [];
  for (let offset = 0; ; offset += PAGE_SIZE) {
    const url = new URL(
      '/rest/v1/liga_card_price_cache',
      supabaseUrl.endsWith('/') ? supabaseUrl : `${supabaseUrl}/`,
    );
    url.searchParams.set('edition_code', `eq.${PROMOTIONAL_EDITION}`);
    url.searchParams.set(
      'select',
      'card_code,card_name,image_url,resolved_at',
    );
    url.searchParams.set('order', 'card_code.asc');
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
      throw new Error(
        `Supabase promotional catalog returned ${response.status}`,
      );
    }

    const page = await response.json();
    if (!Array.isArray(page)) {
      throw new Error('Unexpected Supabase promotional catalog payload');
    }
    rows.push(...page);
    if (page.length < PAGE_SIZE) break;
  }
  return rows;
}

module.exports = {
  PROMOTIONAL_EDITION,
  PROMOTIONAL_SET_NAME,
  baseCardCode,
  fetchPromotionalCards,
  mergePromotionalCards,
};
