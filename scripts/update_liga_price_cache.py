import argparse
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CACHE_PATH = ROOT / "assets" / "liga_one_piece_price_cache.json"
API_URLS = (
    "https://www.optcgapi.com/api/allSetCards/?format=json",
    "https://www.optcgapi.com/api/allSTCards/?format=json",
    "https://www.optcgapi.com/api/allPromos/?format=json",
)
AUTOCOMPLETE_URL = (
    "https://www.clubedaliga.com.br/api/cardsearch?tcg=11&maxQuantity=12&maintype=1&"
)
LIGA_BASE_URL = "https://www.ligaonepiece.com.br/?"
USER_AGENT = "Mozilla/5.0 OPTCG-Manager Cache Builder"


def load_env():
    env = dict(os.environ)
    env_path = ROOT / ".env"
    if not env_path.exists():
        return env

    for line in env_path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", line.strip())
        if not match:
            continue
        key, value = match.groups()
        value = value.strip().strip('"').strip("'")
        env.setdefault(key, value)
    return env


def fetch_json(url: str):
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/json,text/plain,*/*",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def fetch_text(url: str) -> str:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/126.0.0.0 Safari/537.36"
            ),
            "Accept": (
                "text/html,application/xhtml+xml,application/xml;q=0.9,"
                "image/avif,image/webp,image/apng,*/*;q=0.8"
            ),
            "Accept-Language": "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8", "replace")


def normalize_code(code: str) -> str:
    return code.strip().upper()


def clean_name(name: str, code: str) -> str:
    value = name.strip()
    value = re.sub(
        r"\s*-\s*[A-Z]{1,4}\d{2}-\d{3}(?:-[A-Z0-9]+)?",
        "",
        value,
    )
    value = value.replace("(Reprint)", "")
    value = re.sub(
        r"\s*\((?:Alternate Art|Alt Art|SP|Parallel|Manga|Special|Treasure|Wanted)\)",
        "",
        value,
        flags=re.IGNORECASE,
    )
    value = re.sub(r"\s+", " ", value).strip()
    return value


def infer_edition(code: str) -> str:
    match = re.match(r"^([A-Z]{1,4})(\d{2})-\d{3}(?:-[A-Z0-9]+)?$", code)
    if not match:
        return ""
    prefix = match.group(1)
    number = match.group(2)
    if prefix == "EB":
        return f"{prefix}{number}"
    return f"{prefix}-{number}"


def build_current_descriptor(name: str, code: str) -> str:
    cleaned = clean_name(name, code)
    is_reprint = "reprint" in name.lower() or code.endswith("-RE")
    liga_code = code if (not is_reprint or code.endswith("-RE")) else f"{code}-RE"
    match = re.search(r"-(\d{3})", liga_code)
    number_label = match.group(1) if match else ""

    parts = [cleaned]
    if number_label:
        parts.append(f"({number_label})")
    if is_reprint:
        parts.append("(Reprint)")
    parts.append(f"({liga_code})")
    return " ".join(parts)


def special_suffixes_for_name(name: str):
    normalized = re.sub(r"[^a-z0-9]+", " ", (name or "").lower()).strip()
    suffixes = []
    if "sp" in normalized.split():
        suffixes.append(("SP", "SP"))
    if "alternate art" in normalized or "alt art" in normalized:
        suffixes.append(("Alternate Art", "AA"))
    if "parallel" in normalized:
        suffixes.append(("Parallel", "PA"))
    return suffixes


def lookup_code_for_card(name: str, code: str) -> str:
    normalized_code = normalize_code(code)
    suffixes = special_suffixes_for_name(name)
    if suffixes and normalized_code:
        return f"{normalized_code}-{suffixes[0][1]}"
    return normalized_code


def is_special_descriptor(descriptor: str, code: str) -> bool:
    normalized = descriptor.lower()
    return (
        f"{code.lower()}-sp" in normalized
        or f"{code.lower()}-aa" in normalized
        or f"{code.lower()}-pa" in normalized
        or "(sp)" in normalized
        or "alternate art" in normalized
        or "parallel" in normalized
    )


def build_candidate_descriptors(name: str, code: str):
    candidates = []

    def add(value: str):
        normalized = re.sub(r"\s+", " ", value).strip()
        if normalized and normalized not in candidates:
            candidates.append(normalized)

    cleaned = clean_name(name, code)
    for label, suffix in special_suffixes_for_name(name):
        add(f"{cleaned} ({label}) ({code}-{suffix})")
    add(f"{cleaned} ({code})")
    add(build_current_descriptor(name, code))
    add(cleaned)

    for query in (f"{cleaned} ({code})", code, cleaned):
        for suggestion in fetch_autocomplete_suggestions(query, code):
            add(suggestion)

    return candidates


def fetch_autocomplete_suggestions(query: str, code: str):
    url = AUTOCOMPLETE_URL + urllib.parse.urlencode({"query": query})
    try:
        payload = fetch_json(url)
    except Exception:
        return []

    suggestions = payload.get("suggestions") or []
    normalized_base = code.replace("-RE", "")
    results = []
    for suggestion in suggestions:
        text = str(suggestion).strip()
        if code in text or normalized_base in text:
            results.append(text)
    return results


def build_candidate_urls(name: str, code: str):
    descriptors = build_candidate_descriptors(name, code)
    edition = infer_edition(code)
    card_urls = []
    search_urls = []
    priority_search_urls = []
    wants_special = bool(special_suffixes_for_name(name))

    direct_descriptors = [
        build_current_descriptor(name, code),
        f"{clean_name(name, code)} ({code})",
        clean_name(name, code),
    ]

    if edition:
        for descriptor in direct_descriptors + descriptors:
            card_url = LIGA_BASE_URL + urllib.parse.urlencode(
                {
                    "view": "cards/card",
                    "card": descriptor,
                    "ed": edition,
                    "num": code,
                }
            )
            card_urls.append((descriptor, card_url))

    for descriptor in descriptors:
        search_url = LIGA_BASE_URL + urllib.parse.urlencode(
            {
                "view": "cards/search",
                "card": descriptor,
                "tipo": "1",
            }
        )
        if wants_special and is_special_descriptor(descriptor, code):
            priority_search_urls.append((descriptor, search_url))
        else:
            search_urls.append((descriptor, search_url))

    deduped = []
    seen = set()
    for descriptor, url in priority_search_urls + card_urls + search_urls:
        if url in seen:
            continue
        seen.add(url)
        deduped.append((descriptor, url))
    return deduped


def extract_assignment(html: str, variable_name: str):
    match = re.search(
        rf"{re.escape(variable_name)}\s*=\s*([\[\{{][\s\S]*?[\]\}}]);",
        html,
        re.MULTILINE,
    )
    return match.group(1) if match else None


def parse_money(value):
    if value is None:
        return None
    raw = str(value).strip()
    if not raw:
        return None
    normalized = raw.replace(".", "").replace(",", ".") if "," in raw else raw
    try:
        return float(normalized)
    except ValueError:
        try:
            return float(raw)
        except ValueError:
            return None


def wants_foil_price(card_name: str) -> bool:
    normalized = re.sub(r"[^a-z0-9]+", " ", (card_name or "").lower()).strip()
    special_markers = (
        "alternate art",
        "alt art",
        "parallel",
        "manga",
        "special",
        "treasure",
        "wanted",
        "sp",
    )
    return any(marker in normalized.split() for marker in ("sp",)) or any(
        marker in normalized for marker in special_markers if marker != "sp"
    )


def select_price_map(raw_price, prefer_foil: bool):
    if isinstance(raw_price, list):
        if not raw_price:
            return {}
        foil_index = 2 if len(raw_price) > 2 else 1
        index = foil_index if prefer_foil else 0
        return raw_price[index] if index < len(raw_price) else raw_price[0]

    if not isinstance(raw_price, dict):
        return {}

    if prefer_foil:
        for key in ("2", "1"):
            price_map = raw_price.get(key)
            if isinstance(price_map, dict):
                return price_map

    price_map = raw_price.get("0")
    if isinstance(price_map, dict):
        return price_map

    for value in raw_price.values():
        if isinstance(value, dict):
            return value

    return raw_price


def normalize_asset_url(raw: str) -> str:
    if not raw:
        return ""
    if raw.startswith("//"):
        return f"https:{raw}"
    return raw


def extract_card_name(html: str):
    match = re.search(
        r'<div class="item-name">\s*([^<]+)\s*</div>',
        html,
        re.MULTILINE,
    )
    return match.group(1).strip() if match else None


def parse_snapshot(html: str, source_url: str, lookup_code: str, card_name: str = ""):
    editions_raw = extract_assignment(html, "cards_editions")
    stock_raw = extract_assignment(html, "cards_stock")
    stores_raw = extract_assignment(html, "cards_stores")

    if not editions_raw:
        return None

    try:
        editions = json.loads(editions_raw)
        stock = json.loads(stock_raw) if stock_raw else []
        stores = json.loads(stores_raw) if stores_raw else {}
    except Exception:
        return None

    if not editions:
        return None

    edition = editions[0]
    raw_price = edition.get("price") or {}
    prefer_foil = wants_foil_price(card_name)
    price_map = select_price_map(raw_price, prefer_foil)
    desired_extra = 2 if prefer_foil else 0

    listings = []
    for item in stock:
        if item.get("extras") is not None:
            try:
                if int(item.get("extras") or 0) != desired_extra:
                    continue
            except (TypeError, ValueError):
                pass
        price = parse_money(item.get("precoFinal"))
        if price is None:
            continue
        listings.append(
            {
                "id": int(item.get("id") or 0),
                "quantity": int(item.get("quant") or 0),
                "price": price,
                "storeId": int(item.get("lj_id") or 0),
                "state": str(item.get("lj_uf") or "").strip(),
            }
        )

    listings.sort(key=lambda item: item["price"])
    lowest_listing = listings[0] if listings else None
    lowest_store = None
    if lowest_listing:
        store = stores.get(str(lowest_listing["storeId"])) or {}
        lowest_store = {
            "name": str(store.get("lj_name") or "").strip(),
            "city": str(store.get("lj_cidade") or "").strip(),
            "state": str(store.get("lj_uf") or "").strip(),
            "phone": str(store.get("lj_tel") or "").strip(),
        }

    return {
        "lookupCode": lookup_code_for_card(card_name, lookup_code),
        "sourceUrl": source_url,
        "cardName": extract_card_name(html) or str(edition.get("name") or "").strip(),
        "cardCode": str(edition.get("num") or lookup_code).strip().upper(),
        "editionCode": str(edition.get("code") or "").strip(),
        "imageUrl": normalize_asset_url(str(edition.get("img") or "").strip()),
        "minimumPrice": parse_money(price_map.get("p")),
        "averagePrice": parse_money(price_map.get("m")),
        "maximumPrice": parse_money(price_map.get("g")),
        "listingCount": len(listings),
        "lowestListing": lowest_listing,
        "lowestStore": lowest_store,
    }


def snapshot_to_supabase_row(snapshot):
    return {
        "lookup_code": normalize_code(str(snapshot.get("lookupCode") or "")),
        "source_url": snapshot.get("sourceUrl"),
        "card_name": snapshot.get("cardName"),
        "card_code": normalize_code(str(snapshot.get("cardCode") or "")),
        "edition_code": snapshot.get("editionCode"),
        "image_url": snapshot.get("imageUrl"),
        "minimum_price": snapshot.get("minimumPrice"),
        "average_price": snapshot.get("averagePrice"),
        "maximum_price": snapshot.get("maximumPrice"),
        "listing_count": snapshot.get("listingCount") or 0,
        "lowest_listing": snapshot.get("lowestListing"),
        "lowest_store": snapshot.get("lowestStore"),
        "used_verified_fallback": False,
        "note": "Coletado localmente pelo script update_liga_price_cache.py.",
        "resolved_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


def upsert_supabase_snapshots(snapshots):
    rows = [
        snapshot_to_supabase_row(snapshot)
        for snapshot in snapshots
        if normalize_code(str(snapshot.get("lookupCode") or ""))
    ]
    return upsert_supabase_rows(rows)


def upsert_supabase_rows(rows):
    env = load_env()
    supabase_url = (env.get("SUPABASE_URL") or "").rstrip("/")
    service_key = env.get("SUPABASE_SERVICE_ROLE_KEY") or ""
    if not supabase_url or not service_key:
        raise RuntimeError(
            "SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY precisam existir no .env."
        )

    if not rows:
        return 0

    url = (
        f"{supabase_url}/rest/v1/liga_card_price_cache?"
        "on_conflict=lookup_code"
    )
    request = urllib.request.Request(
        url,
        data=json.dumps(rows, ensure_ascii=False).encode("utf-8"),
        method="POST",
        headers={
            "apikey": service_key,
            "authorization": f"Bearer {service_key}",
            "content-type": "application/json",
            "prefer": "resolution=merge-duplicates",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        response.read()
        if response.status not in (200, 201, 204):
            raise RuntimeError(f"Supabase retornou HTTP {response.status}.")
    return len(rows)


def fetch_snapshot_for_card(name: str, code: str):
    for descriptor, url in build_candidate_urls(name, code):
        try:
            html = fetch_text(url)
        except Exception:
            time.sleep(0.15)
            continue

        snapshot = parse_snapshot(html, url, code, name)
        if snapshot is not None:
            snapshot["resolvedWith"] = descriptor
            return snapshot

        time.sleep(0.1)

    return None


def load_cards():
    grouped = {}

    for url in API_URLS:
        for item in fetch_json(url):
            code = normalize_code(str(item.get("card_set_id") or ""))
            if not code:
                continue

            candidate = {
                "code": code,
                "name": str(item.get("card_name") or "").strip(),
                "image": str(item.get("card_image") or "").strip(),
            }

            current = grouped.get(code)
            if current is None:
                grouped[code] = candidate
                continue

            if not current["image"] and candidate["image"]:
                grouped[code] = candidate

    return list(grouped.values())


def save_cache(cards):
    payload = {
        "updatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "cards": cards,
    }
    CACHE_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def parse_args():
    parser = argparse.ArgumentParser(
        description="Atualiza o cache de preços da LigaOnePiece."
    )
    parser.add_argument(
        "legacy_limit",
        nargs="?",
        type=int,
        help="Compatibilidade: limite de cartas para gerar o JSON local.",
    )
    parser.add_argument("--limit", type=int, help="Limite de cartas para processar.")
    parser.add_argument("--code", help="Codigo de uma carta especifica, ex: EB01-001.")
    parser.add_argument("--name", help="Nome da carta especifica.")
    parser.add_argument(
        "--supabase",
        action="store_true",
        help="Grava os resultados em liga_card_price_cache no Supabase.",
    )
    parser.add_argument(
        "--no-asset",
        action="store_true",
        help="Nao atualiza assets/liga_one_piece_price_cache.json.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    limit = args.limit if args.limit is not None else args.legacy_limit

    if args.code:
        code = normalize_code(args.code)
        name = args.name or code
        snapshot = fetch_snapshot_for_card(name, code)
        if snapshot is None:
            raise RuntimeError(f"Nao foi possivel resolver {code} na LigaOnePiece.")

        print(
            json.dumps(
                {
                    "lookupCode": snapshot["lookupCode"],
                    "cardName": snapshot["cardName"],
                    "minimumPrice": snapshot["minimumPrice"],
                    "listingCount": snapshot["listingCount"],
                    "lowestListing": snapshot["lowestListing"],
                    "lowestStore": snapshot["lowestStore"],
                    "resolvedWith": snapshot.get("resolvedWith"),
                },
                ensure_ascii=False,
                indent=2,
            )
        )

        if args.supabase:
            count = upsert_supabase_snapshots([snapshot])
            print(f"Supabase atualizado com {count} carta.")
        return

    all_cards = load_cards()
    if limit is not None:
        all_cards = all_cards[:limit]

    existing = {}
    if CACHE_PATH.exists():
        try:
            cached_payload = json.loads(CACHE_PATH.read_text(encoding="utf-8"))
            for item in cached_payload.get("cards", []):
                code = normalize_code(str(item.get("lookupCode") or ""))
                if code:
                    existing[code] = item
        except Exception:
            existing = {}

    resolved = []
    success = 0

    for index, card in enumerate(all_cards, start=1):
        code = card["code"]
        name = card["name"]
        snapshot = fetch_snapshot_for_card(name, code)
        if snapshot is None:
            snapshot = existing.get(code)

        if snapshot is not None:
            resolved.append(snapshot)
            success += 1

        if index % 25 == 0 or index == len(all_cards):
            print(f"[{index}/{len(all_cards)}] resolvidas: {success}")
            if not args.no_asset:
                save_cache(resolved)

    if args.supabase:
        count = upsert_supabase_snapshots(resolved)
        print(f"Supabase atualizado com {count} cartas.")

    if not args.no_asset:
        print(f"Cache final salvo com {success} cartas.")


if __name__ == "__main__":
    main()
