"""Audita e persiste pareamentos seguros entre o catalogo One Piece e a Liga."""

from __future__ import annotations

import argparse
import json
import re
import time
import urllib.parse
import urllib.request
from collections import defaultdict
from pathlib import Path

import update_liga_price_cache as liga


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "assets" / "one_piece_cards_cache.json"
MAPPING_TABLE = "liga_card_variant_mappings"
AUDIT_TABLE = "liga_price_audit_runs"
PRICE_TABLE = "liga_card_price_cache"
PAGE_SIZE = 1000
UPSERT_BATCH_SIZE = 250
SUFFIX_PATTERN = re.compile(
    r"-(AA|DP|FA|G|MA|OP|PA|PAR|PR|RE|RW|SP|TC|TR|WP|E|A|P)$"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Audita variantes One Piece e grava os resultados no Supabase."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Calcula os resultados sem gravar no Supabase.",
    )
    return parser.parse_args()


def normalize_text(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", value.lower()).strip()


def base_code(value: str) -> str:
    normalized = value.strip().upper().split("@", 1)[0]
    return SUFFIX_PATTERN.sub("", normalized)


def suffix(value: str) -> str:
    normalized = value.strip().upper().split("@", 1)[0]
    match = SUFFIX_PATTERN.search(normalized)
    return match.group(1) if match else ""


def classify(name: str, code: str) -> str:
    text = normalize_text(name)
    tokens = set(text.split())
    code_suffix = suffix(code)
    if "manga" in text or code_suffix == "MA":
        return "manga"
    if "treasure cup" in text or code_suffix == "TC":
        return "treasure_cup"
    if "treasure rare" in text or code_suffix == "TR":
        return "treasure_rare"
    if "welcome pack" in text:
        return "welcome_pack"
    if "winner pack" in text or code_suffix == "WP":
        return "winner_pack"
    if "winner" in text or code_suffix == "RW":
        return "winner"
    if "finalist" in text:
        return "finalist"
    if "participant" in text or "participation" in text or code_suffix == "OP":
        return "participant"
    if "pre release" in text or "prerelease" in text or code_suffix == "PR":
        return "pre_release"
    if "release event" in text or code_suffix == "RE":
        return "reprint" if "reprint" in text else "release_event"
    if "dash pack" in text or code_suffix == "DP":
        return "dash_pack"
    if "full art" in text or code_suffix == "FA":
        return "full_art"
    if "gold" in text or code_suffix == "G":
        return "gold"
    if "reprint" in text:
        return "reprint"
    if tokens.intersection({"sp", "spr"}) or "special" in text or code_suffix == "SP":
        return "special"
    if "parallel" in text or code_suffix in {"PA", "PAR", "E", "A", "P"}:
        return "parallel"
    if "alternate art" in text or "alt art" in text or code_suffix == "AA":
        return "alternate_art"
    if any(
        marker in text
        for marker in (
            "regional",
            "championship",
            "event pack",
            "promotion pack",
            "promo pack",
            "gift collection",
            "trophy card",
        )
    ):
        return "promotional"
    return "normal"


def primary_lookup_code(name: str, code: str) -> str:
    normalized = code.strip().upper()
    if suffix(normalized):
        return normalized
    kind_suffix = {
        "alternate_art": "AA",
        "manga": "MA",
        "treasure_cup": "TC",
        "treasure_rare": "TR",
        "welcome_pack": "WP",
        "winner_pack": "WP",
        "winner": "RW",
        "participant": "OP",
        "pre_release": "PR",
        "release_event": "RE",
        "dash_pack": "DP",
        "full_art": "FA",
        "gold": "G",
        "special": "SP",
        "parallel": "PA",
        "reprint": "RE",
    }.get(classify(name, normalized), "")
    return f"{base_code(normalized)}-{kind_suffix}" if kind_suffix else normalized


def image_identity(value: str) -> str:
    path = urllib.parse.urlparse(value.strip()).path
    filename = path.rsplit("/", 1)[-1].lower()
    return re.sub(r"[^a-z0-9]+", "", filename)


def variant_key(card: dict) -> str:
    lookup = primary_lookup_code(
        str(card.get("card_name") or ""), str(card.get("card_set_id") or "")
    )
    identity = image_identity(str(card.get("card_image") or ""))
    return f"{lookup}::IMG::{identity}" if identity else lookup


def compatible(requested: str, candidate: str, edition: str) -> bool:
    if requested == candidate:
        return True
    if {requested, candidate} <= {"alternate_art", "parallel"}:
        return True
    edition = edition.strip().upper()
    return candidate == "normal" and (
        (requested in {"release_event", "reprint"} and edition.endswith("-RE"))
        or (requested == "pre_release" and edition.endswith("-PR"))
    )


def expected_original_edition(code: str) -> str:
    match = re.match(r"^(OP|EB|ST)(\d{2})-", base_code(code))
    if not match:
        return ""
    prefix, number = match.groups()
    return f"OP-{number}" if prefix == "OP" else f"{prefix}{number}"


def printing_identity(row: dict) -> tuple:
    return (
        str(row.get("card_code") or "").upper(),
        str(row.get("edition_code") or "").upper(),
        str(row.get("image_url") or ""),
        row.get("minimum_price"),
    )


def choose_lookup(rows: list[dict]) -> str:
    scoped = [row for row in rows if "@" in str(row.get("lookup_code") or "")]
    selected = scoped[0] if scoped else rows[0]
    return str(selected.get("lookup_code") or "").strip().upper()


def build_mapping(card: dict, candidates: list[dict]) -> dict:
    card_name = str(card.get("card_name") or "").strip()
    card_code = str(card.get("card_set_id") or "").strip().upper()
    requested = classify(card_name, card_code)
    compatible_rows = [
        row
        for row in candidates
        if row.get("minimum_price") is not None
        and compatible(
            requested,
            classify(
                str(row.get("card_name") or ""),
                str(row.get("card_code") or row.get("lookup_code") or ""),
            ),
            str(row.get("edition_code") or ""),
        )
    ]
    exact_images = [
        row
        for row in compatible_rows
        if image_identity(str(row.get("image_url") or ""))
        == image_identity(str(card.get("card_image") or ""))
    ]
    method = "exact_image" if exact_images else "exact_metadata"
    narrowed = exact_images or compatible_rows
    expected = expected_original_edition(card_code)
    original_rows = [
        row
        for row in narrowed
        if expected and str(row.get("edition_code") or "").upper() == expected
    ]
    if original_rows:
        narrowed = original_rows
    groups: dict[tuple, list[dict]] = defaultdict(list)
    for row in narrowed:
        groups[printing_identity(row)].append(row)

    status = "missing"
    confidence = 0.0
    liga_lookup = None
    liga_edition = None
    liga_image = None
    if len(groups) == 1:
        matched_rows = next(iter(groups.values()))
        selected = matched_rows[0]
        status = "confirmed"
        confidence = 1.0 if exact_images else (0.98 if original_rows else 0.95)
        liga_lookup = choose_lookup(matched_rows)
        liga_edition = selected.get("edition_code")
        liga_image = selected.get("image_url")
    elif len(groups) > 1:
        status = "review"
        method = "ambiguous"

    return {
        "game_slug": "one-piece",
        "catalog_variant_key": variant_key(card),
        "catalog_card_code": card_code,
        "catalog_card_name": card_name,
        "catalog_set_name": str(card.get("set_name") or "").strip() or None,
        "catalog_image_url": str(card.get("card_image") or "").strip() or None,
        "variant_kind": requested,
        "liga_lookup_code": liga_lookup,
        "liga_edition_code": liga_edition,
        "liga_image_url": liga_image,
        "confidence": confidence,
        "match_method": method if status == "confirmed" else status.replace("review", "ambiguous"),
        "status": status,
        "is_manual": False,
        "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


def supabase_config() -> tuple[str, str]:
    env = liga.load_env()
    url = str(env.get("SUPABASE_URL") or "").rstrip("/")
    key = str(env.get("SUPABASE_SERVICE_ROLE_KEY") or "")
    if not url or not key:
        raise RuntimeError("SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY sao obrigatorios.")
    return url, key


def request_json(url: str, key: str, *, method: str = "GET", data=None, prefer=""):
    headers = {"apikey": key, "authorization": f"Bearer {key}"}
    payload = None
    if data is not None:
        payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
        headers["content-type"] = "application/json"
    if prefer:
        headers["prefer"] = prefer
    request = urllib.request.Request(url, data=payload, method=method, headers=headers)
    with urllib.request.urlopen(request, timeout=60) as response:
        body = response.read()
        return json.loads(body) if body else None


def load_price_rows(url: str, key: str) -> list[dict]:
    rows = []
    select = "lookup_code,card_code,card_name,edition_code,image_url,minimum_price"
    one_piece_filter = urllib.parse.quote(
        "(card_code.like.OP*,card_code.like.ST*,card_code.like.EB*,"
        "card_code.like.P-*,card_code.like.PRB*)",
        safe="(),.*-",
    )
    for start in range(0, 1_000_000, PAGE_SIZE):
        endpoint = (
            f"{url}/rest/v1/{PRICE_TABLE}?select={select}"
            f"&or={one_piece_filter}"
            "&order=lookup_code.asc"
        )
        request = urllib.request.Request(
            endpoint,
            headers={
                "apikey": key,
                "authorization": f"Bearer {key}",
                "range": f"{start}-{start + PAGE_SIZE - 1}",
            },
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            page = json.load(response)
        rows.extend(page)
        if len(page) < PAGE_SIZE:
            break
    return rows


def upsert_mappings(url: str, key: str, mappings: list[dict]) -> int:
    priority = {"missing": 0, "review": 1, "confirmed": 2}
    unique_mappings: dict[str, dict] = {}
    for mapping in mappings:
        variant = str(mapping["catalog_variant_key"])
        current = unique_mappings.get(variant)
        if current is None or priority[mapping["status"]] > priority[current["status"]]:
            unique_mappings[variant] = mapping
    consolidated = list(unique_mappings.values())
    endpoint = (
        f"{url}/rest/v1/{MAPPING_TABLE}?"
        "on_conflict=game_slug,catalog_variant_key"
    )
    for start in range(0, len(consolidated), UPSERT_BATCH_SIZE):
        request_json(
            endpoint,
            key,
            method="POST",
            data=consolidated[start : start + UPSERT_BATCH_SIZE],
            prefer="resolution=merge-duplicates",
        )
    return len(consolidated)


def main() -> None:
    args = parse_args()
    url, key = supabase_config()
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8-sig"))
    price_rows = load_price_rows(url, key)
    rows_by_code: dict[str, list[dict]] = defaultdict(list)
    for row in price_rows:
        rows_by_code[base_code(str(row.get("card_code") or ""))].append(row)

    mappings = [
        build_mapping(card, rows_by_code[base_code(str(card.get("card_set_id") or ""))])
        for card in catalog
    ]
    counts = {
        status: sum(1 for row in mappings if row["status"] == status)
        for status in ("confirmed", "review", "missing")
    }
    print(
        f"Catalogo: {len(catalog)} | cache: {len(price_rows)} | "
        f"confirmadas: {counts['confirmed']} | "
        f"revisao: {counts['review']} | ausentes: {counts['missing']}"
    )
    if args.dry_run:
        return

    persisted_count = upsert_mappings(url, key, mappings)
    request_json(
        f"{url}/rest/v1/{AUDIT_TABLE}",
        key,
        method="POST",
        data={
            "game_slug": "one-piece",
            "status": "completed",
            "catalog_card_count": len(catalog),
            "uniquely_matched_count": counts["confirmed"],
            "ambiguous_count": counts["review"],
            "missing_count": counts["missing"],
            "details": {"price_rows": len(price_rows), "algorithm_version": 1},
            "completed_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        },
    )
    print(f"{persisted_count} mapeamentos unicos gravados no Supabase.")


if __name__ == "__main__":
    main()
