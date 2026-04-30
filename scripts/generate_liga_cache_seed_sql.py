import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CACHE_PATH = ROOT / "assets" / "liga_one_piece_price_cache.json"
OUTPUT_PATH = ROOT / "sql" / "liga_card_price_cache_seed.sql"


def sql_text(value: str) -> str:
    escaped = value.replace("'", "''")
    return f"'{escaped}'"


def sql_nullable_text(value):
    if value is None:
        return "null"
    text = str(value)
    return sql_text(text)


def sql_nullable_number(value):
    if value is None:
        return "null"
    return str(value)


def sql_jsonb(value):
    if value is None:
        return "null"
    encoded = json.dumps(value, ensure_ascii=False)
    return f"{sql_text(encoded)}::jsonb"


def build_row(card: dict) -> str:
    return "(" + ", ".join(
        [
            sql_text(str(card.get("lookupCode", "")).strip().upper()),
            sql_text(str(card.get("sourceUrl", "")).strip()),
            sql_text(str(card.get("cardName", "")).strip()),
            sql_text(str(card.get("cardCode", "")).strip().upper()),
            sql_text(str(card.get("editionCode", "")).strip()),
            sql_text(str(card.get("imageUrl", "")).strip()),
            sql_nullable_number(card.get("minimumPrice")),
            sql_nullable_number(card.get("averagePrice")),
            sql_nullable_number(card.get("maximumPrice")),
            str(int(card.get("listingCount", 0) or 0)),
            sql_jsonb(card.get("lowestListing")),
            sql_jsonb(card.get("lowestStore")),
            "true",
            sql_text("Seed gerado a partir do cache local do app."),
            "timezone('utc', now())",
        ]
    ) + ")"


def main():
    payload = json.loads(CACHE_PATH.read_text(encoding="utf-8"))
    cards = payload.get("cards", [])

    header = [
        "-- Seed gerado automaticamente a partir de assets/liga_one_piece_price_cache.json",
        f"-- Cartas: {len(cards)}",
        "",
        "insert into public.liga_card_price_cache (",
        "  lookup_code,",
        "  source_url,",
        "  card_name,",
        "  card_code,",
        "  edition_code,",
        "  image_url,",
        "  minimum_price,",
        "  average_price,",
        "  maximum_price,",
        "  listing_count,",
        "  lowest_listing,",
        "  lowest_store,",
        "  used_verified_fallback,",
        "  note,",
        "  resolved_at",
        ")",
        "values",
    ]

    rows = [build_row(card) for card in cards]

    footer = [
        "on conflict (lookup_code) do update",
        "set",
        "  source_url = excluded.source_url,",
        "  card_name = excluded.card_name,",
        "  card_code = excluded.card_code,",
        "  edition_code = excluded.edition_code,",
        "  image_url = excluded.image_url,",
        "  minimum_price = excluded.minimum_price,",
        "  average_price = excluded.average_price,",
        "  maximum_price = excluded.maximum_price,",
        "  listing_count = excluded.listing_count,",
        "  lowest_listing = excluded.lowest_listing,",
        "  lowest_store = excluded.lowest_store,",
        "  used_verified_fallback = excluded.used_verified_fallback,",
        "  note = excluded.note,",
        "  resolved_at = excluded.resolved_at;",
        "",
    ]

    sql = "\n".join(header) + "\n" + ",\n".join(rows) + "\n" + "\n".join(footer)
    OUTPUT_PATH.write_text(sql, encoding="utf-8")
    print(f"Seed SQL gerado em: {OUTPUT_PATH}")
    print(f"Cartas incluídas: {len(cards)}")


if __name__ == "__main__":
    main()
