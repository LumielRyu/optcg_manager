import json
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
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
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
    value = re.sub(r"\s+", " ", value).strip()
    return value


def infer_edition(code: str) -> str:
    match = re.match(r"^([A-Z]{1,4})(\d{2})-\d{3}(?:-[A-Z0-9]+)?$", code)
    if not match:
        return ""
    return f"{match.group(1)}-{match.group(2)}"


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


def build_candidate_descriptors(name: str, code: str):
    candidates = []

    def add(value: str):
        normalized = re.sub(r"\s+", " ", value).strip()
        if normalized and normalized not in candidates:
            candidates.append(normalized)

    cleaned = clean_name(name, code)
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
    urls = []

    for descriptor in descriptors:
        search_url = LIGA_BASE_URL + urllib.parse.urlencode(
            {
                "view": "cards/search",
                "card": descriptor,
                "tipo": "1",
            }
        )
        urls.append((descriptor, search_url))

    if edition:
        for descriptor in descriptors:
            card_url = LIGA_BASE_URL + urllib.parse.urlencode(
                {
                    "view": "cards/card",
                    "card": descriptor,
                    "ed": edition,
                    "num": code,
                }
            )
            urls.append((descriptor, card_url))

    deduped = []
    seen = set()
    for descriptor, url in urls:
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
    normalized = raw.replace(".", "").replace(",", ".")
    try:
        return float(normalized)
    except ValueError:
        try:
            return float(raw)
        except ValueError:
            return None


def normalize_asset_url(raw: str) -> str:
    if not raw:
        return ""
    if raw.startswith("//"):
        return f"https:{raw}"
    return raw


def parse_snapshot(html: str, source_url: str, lookup_code: str):
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
    if isinstance(raw_price, dict):
        price_map = raw_price.get("0") or raw_price
    else:
        price_map = {}

    listings = []
    for item in stock:
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
        "lookupCode": lookup_code,
        "sourceUrl": source_url,
        "cardName": str(edition.get("name") or "").strip(),
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


def fetch_snapshot_for_card(name: str, code: str):
    for descriptor, url in build_candidate_urls(name, code):
        try:
            html = fetch_text(url)
        except Exception:
            time.sleep(0.15)
            continue

        snapshot = parse_snapshot(html, url, code)
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


def main():
    limit = None
    if len(sys.argv) > 1:
        try:
            limit = int(sys.argv[1])
        except ValueError:
            limit = None

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
            save_cache(resolved)

    print(f"Cache final salvo com {success} cartas.")


if __name__ == "__main__":
    main()
