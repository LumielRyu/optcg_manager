const PAGE_SIZE = 1000;

function normalizeText(value) {
  return String(value ?? '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function normalizeCardName(value) {
  return normalizeText(
    String(value ?? '')
      .replace(/[A-Z]{1,4}\d{2}-\d{3}(?:-[A-Z0-9]+)?/gi, ' ')
      .replace(/\(\d{3}\)/g, ' '),
  );
}

function normalizeEditionCode(value) {
  const normalized = String(value ?? '')
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '');
  const match = /^([A-Z]+)0*(\d+)$/.exec(normalized);
  return match ? `${match[1]}${Number(match[2])}` : normalized;
}

function baseCardCode(value) {
  const code = String(value ?? '').trim().toUpperCase();
  const match = /^(.+-\d{3})(?:-[A-Z0-9]+)?$/.exec(code);
  return match?.[1] ?? code;
}

function printingNames(card) {
  const name = normalizeCardName(card?.card_name);
  const names = new Set([name]);

  // A Liga chama a variante manga de "Parallel" em algumas edicoes,
  // enquanto a API oficial a identifica como "Manga".
  if (name.endsWith(' manga')) {
    names.add(name.replace(/ manga$/, ' parallel'));
  } else if (name.endsWith(' parallel')) {
    names.add(name.replace(/ parallel$/, ' manga'));
  }

  return names;
}

function printingIndexKeys(card) {
  const baseCode = baseCardCode(card?.card_set_id);
  return [...printingNames(card)].map((name) => `${baseCode}|${name}`);
}

function samePrintingEdition(first, second) {
  const firstEdition = normalizeEditionCode(first?.set_id);
  const secondEdition = normalizeEditionCode(second?.set_id);
  if (firstEdition && secondEdition && firstEdition === secondEdition) {
    return true;
  }

  const firstSet = normalizeText(first?.set_name);
  const secondSet = normalizeText(second?.set_name);
  return Boolean(firstSet && secondSet && firstSet === secondSet);
}

function hasEquivalentPrinting(card, printingIndex) {
  for (const key of printingIndexKeys(card)) {
    const candidates = printingIndex.get(key) ?? [];
    const cardImage = String(card?.card_image ?? '').trim();
    if (
      candidates.some((candidate) => {
        const candidateImage = String(candidate?.card_image ?? '').trim();
        return (
          samePrintingEdition(candidate, card) ||
          (cardImage && candidateImage === cardImage)
        );
      })
    ) {
      return true;
    }
  }
  return false;
}

function indexPrinting(card, printingIndex) {
  for (const key of printingIndexKeys(card)) {
    const candidates = printingIndex.get(key) ?? [];
    candidates.push(card);
    printingIndex.set(key, candidates);
  }
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
  const printingIndex = new Map();

  for (const card of merged) {
    const code = String(card?.card_set_id ?? '').trim().toUpperCase();
    if (code && !cardsByCode.has(code)) cardsByCode.set(code, card);
    indexPrinting(card, printingIndex);
  }

  for (const row of catalogRows ?? []) {
    const catalogCard = toCatalogCard(row, cardsByCode);
    if (!catalogCard.card_set_id || !catalogCard.card_image) continue;

    if (hasEquivalentPrinting(catalogCard, printingIndex)) continue;

    indexPrinting(catalogCard, printingIndex);
    merged.push(catalogCard);
  }

  return merged;
}

async function fetchCatalogCards({
  fetchImpl = fetch,
  supabaseUrl,
  supabaseAnonKey,
  retryDelayMs = 250,
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

    const response = await fetchSupabasePageWithRetry({
      fetchImpl,
      url,
      supabaseAnonKey,
      retryDelayMs,
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

async function fetchSupabasePageWithRetry({
  fetchImpl,
  url,
  supabaseAnonKey,
  retryDelayMs,
}) {
  let lastError;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const response = await fetchImpl(url, {
        headers: {
          Accept: 'application/json',
          apikey: supabaseAnonKey,
          Authorization: `Bearer ${supabaseAnonKey}`,
        },
      });
      const retryable = response.status === 429 || response.status >= 500;
      if (!retryable || attempt === 2) return response;
    } catch (error) {
      lastError = error;
      if (attempt === 2) throw error;
    }
    if (retryDelayMs > 0) {
      await new Promise((resolve) =>
        setTimeout(resolve, retryDelayMs * (attempt + 1)),
      );
    }
  }
  throw lastError ?? new Error('Supabase card catalog request failed');
}

module.exports = {
  PAGE_SIZE,
  baseCardCode,
  fetchCatalogCards,
  mergeCatalogCards,
  normalizeCardName,
  normalizeEditionCode,
  toCatalogCard,
};
