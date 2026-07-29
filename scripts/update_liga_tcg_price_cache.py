import argparse
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone

import update_liga_price_cache as liga


DEFAULT_CRAWL_DELAY_SECONDS = 30.0
DEFAULT_BATCH_SIZE = 250

GAME_CONFIGS = {
    "pokemon": {
        "host": "www.ligapokemon.com.br",
        "label": "Pokemon",
    },
    "digimon": {
        "host": "www.ligadigimon.com.br",
        "label": "Digimon",
    },
    "magic": {
        "host": "www.ligamagic.com.br",
        "label": "Magic",
    },
    "riftbound": {
        "host": "www.ligariftbound.com.br",
        "label": "Riftbound",
    },
    "yugioh": {
        "host": "www.ligayugioh.com.br",
        "label": "Yu-Gi-Oh",
    },
}


@dataclass(frozen=True)
class LigaTcgEdition:
    game: str
    edition_id: int
    acronym: str
    name: str
    release_date: str
    group: str

    @property
    def source_url(self) -> str:
        host = GAME_CONFIGS[self.game]["host"]
        query = urllib.parse.urlencode(
            {
                "view": "cards/search",
                "card": f"edid={self.edition_id} ed={self.acronym}",
            }
        )
        return f"https://{host}/?{query}"


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Atualiza o cache compartilhado de precos da Liga para os TCGs "
            "alem de One Piece."
        )
    )
    parser.add_argument("--game", choices=sorted(GAME_CONFIGS), required=True)
    parser.add_argument(
        "--edition",
        action="append",
        default=[],
        help="Atualiza somente a sigla informada. Pode ser repetido.",
    )
    parser.add_argument("--shard-count", type=int, default=1)
    parser.add_argument(
        "--shard-index",
        default="0",
        help="Indice numerico do shard ou 'auto' para alternar a cada 8 horas.",
    )
    parser.add_argument("--priority-editions", type=int, default=3)
    parser.add_argument("--delay", type=float, default=DEFAULT_CRAWL_DELAY_SECONDS)
    parser.add_argument("--limit", type=int)
    parser.add_argument(
        "--include-future",
        action="store_true",
        help="Inclui edições já publicadas pela Liga antes da data de lançamento.",
    )
    parser.add_argument(
        "--missing-only",
        action="store_true",
        help=(
            "Processa somente edições cujo ID da Liga ainda não aparece no "
            "cache. Útil para cargas iniciais retomáveis."
        ),
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def parse_editions_page(
    source: str,
    game: str,
    *,
    include_future: bool = False,
) -> list[LigaTcgEdition]:
    raw = liga.extract_assignment(source, "jsonEditions")
    if not raw:
        raise RuntimeError("jsonEditions nao foi encontrado na pagina de edicoes.")

    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as error:
        raise RuntimeError("jsonEditions retornou JSON invalido.") from error

    editions = []
    seen = set()
    for group in ("main", "aux"):
        group_payload = payload.get(group) or []
        if isinstance(group_payload, dict):
            items = [
                item
                for nested in group_payload.values()
                if isinstance(nested, list)
                for item in nested
            ]
        elif isinstance(group_payload, list):
            items = group_payload
        else:
            items = []

        for item in items:
            if not isinstance(item, dict):
                continue
            acronym = str(item.get("acronym") or "").strip()
            try:
                edition_id = int(item.get("id") or 0)
            except (TypeError, ValueError):
                edition_id = 0
            if not acronym or edition_id <= 0 or edition_id in seen:
                continue
            release_date = str(item.get("dtrelease") or "").strip()
            if not include_future and _is_future_release(release_date):
                continue
            seen.add(edition_id)
            editions.append(
                LigaTcgEdition(
                    game=game,
                    edition_id=edition_id,
                    acronym=acronym,
                    name=str(
                        item.get("namept")
                        or item.get("name")
                        or item.get("nameen")
                        or acronym
                    ).strip(),
                    release_date=release_date,
                    group=group,
                )
            )

    editions.sort(
        key=lambda edition: (edition.release_date, edition.edition_id),
        reverse=True,
    )
    return editions


def fetch_editions(
    game: str,
    *,
    include_future: bool = False,
) -> list[LigaTcgEdition]:
    host = GAME_CONFIGS[game]["host"]
    source = liga.fetch_text(f"https://{host}/?view=cards/edicoes")
    return parse_editions_page(source, game, include_future=include_future)


def fetch_cached_edition_ids(game: str, *, page_size: int = 1000) -> set[int]:
    env = liga.load_env()
    supabase_url = (env.get("SUPABASE_URL") or "").rstrip("/")
    api_key = (
        env.get("SUPABASE_SERVICE_ROLE_KEY")
        or env.get("SUPABASE_ANON_KEY")
        or ""
    )
    if not supabase_url or not api_key:
        raise RuntimeError(
            "SUPABASE_URL e uma chave do Supabase precisam existir no .env."
        )

    prefix = f"{game.upper()}:"
    edition_ids: set[int] = set()
    start = 0
    while True:
        query = urllib.parse.urlencode(
            {
                "select": "note,source_url",
                "lookup_code": f"like.{prefix}*",
                "order": "lookup_code.asc",
            }
        )
        request = urllib.request.Request(
            f"{supabase_url}/rest/v1/liga_card_price_cache?{query}",
            headers={
                "apikey": api_key,
                "authorization": f"Bearer {api_key}",
                "range": f"{start}-{start + page_size - 1}",
            },
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            page = json.load(response)
        for row in page:
            edition_id = extract_cached_edition_id(row)
            if edition_id is not None:
                edition_ids.add(edition_id)
        if len(page) < page_size:
            break
        start += page_size
    return edition_ids


def extract_cached_edition_id(row: dict) -> int | None:
    note = str(row.get("note") or "")
    match = re.search(r"Liga ID\s+(\d+)", note, flags=re.IGNORECASE)
    if match:
        return int(match.group(1))

    source_url = str(row.get("source_url") or "")
    decoded_url = urllib.parse.unquote_plus(source_url)
    match = re.search(r"\bedid=(\d+)\b", decoded_url, flags=re.IGNORECASE)
    return int(match.group(1)) if match else None


def select_missing_editions(
    editions: list[LigaTcgEdition],
    cached_edition_ids: set[int],
) -> list[LigaTcgEdition]:
    return [
        edition
        for edition in editions
        if edition.edition_id not in cached_edition_ids
    ]


def resolve_shard_index(raw_index: str, shard_count: int) -> int:
    if shard_count <= 0:
        raise ValueError("--shard-count precisa ser maior que zero.")
    if raw_index.strip().lower() == "auto":
        return int(time.time() // (8 * 60 * 60)) % shard_count
    try:
        shard_index = int(raw_index)
    except ValueError as error:
        raise ValueError("--shard-index precisa ser numerico ou 'auto'.") from error
    if shard_index < 0 or shard_index >= shard_count:
        raise ValueError("--shard-index esta fora do intervalo.")
    return shard_index


def select_editions(
    editions: list[LigaTcgEdition],
    *,
    requested: list[str],
    shard_count: int,
    shard_index: int,
    priority_count: int,
) -> list[LigaTcgEdition]:
    normalized_requested = {
        value.strip().upper() for value in requested if value.strip()
    }
    if normalized_requested:
        selected = [
            edition
            for edition in editions
            if edition.acronym.upper() in normalized_requested
        ]
        missing = normalized_requested - {
            edition.acronym.upper() for edition in selected
        }
        if missing:
            raise RuntimeError(
                "Edicoes nao encontradas: " + ", ".join(sorted(missing))
            )
        return selected

    priority_count = max(0, min(priority_count, len(editions)))
    priority = editions[:priority_count]
    rotating = [
        edition
        for index, edition in enumerate(editions[priority_count:])
        if index % shard_count == shard_index
    ]
    return priority + rotating


def parse_edition_cards_page(
    source: str,
    edition: LigaTcgEdition,
    *,
    resolved_at: str,
) -> list[dict]:
    raw = liga.extract_assignment(source, "cardsjson")
    if not raw:
        raise RuntimeError(
            f"cardsjson nao foi encontrado para a edicao {edition.acronym}."
        )
    try:
        cards = json.loads(raw)
    except json.JSONDecodeError as error:
        raise RuntimeError(
            f"cardsjson retornou JSON invalido para {edition.acronym}."
        ) from error

    rows = []
    seen = set()
    for item in cards:
        if not isinstance(item, dict):
            continue
        card_number = normalize_card_number(str(item.get("sN") or ""))
        if not card_number:
            continue
        lookup_code = build_lookup_code(
            edition.game,
            edition.acronym,
            card_number,
        )
        if edition.group == "aux":
            lookup_code = f"{lookup_code}@{edition.acronym.upper()}"
        if lookup_code in seen:
            continue
        seen.add(lookup_code)

        exact_code = liga.normalize_code(str(item.get("sN") or ""))
        rows.append(
            {
                "lookup_code": lookup_code,
                "source_url": edition.source_url,
                "card_name": clean_card_name(
                    str(item.get("nPT") or item.get("nEN") or exact_code),
                    exact_code,
                ),
                "card_code": lookup_code,
                "edition_code": edition.acronym,
                "image_url": liga.normalize_asset_url(
                    str(item.get("sP") or "").strip()
                ),
                "minimum_price": safe_price(
                    item.get("precoMenor") or item.get("p1a")
                ),
                "average_price": safe_price(item.get("p1b")),
                "maximum_price": safe_price(
                    item.get("precoMaior") or item.get("p1c")
                ),
                "used_verified_fallback": False,
                "note": (
                    f"TCG={edition.game}; coletado da edicao "
                    f"{edition.acronym} (Liga ID {edition.edition_id})."
                ),
                "resolved_at": resolved_at,
            }
        )
    return rows


def build_lookup_code(game: str, edition_code: str, card_number: str) -> str:
    edition = edition_code.strip().upper()
    number = normalize_card_number(card_number)
    prefix = game.strip().upper()
    if game in {"digimon", "yugioh"} and "-" in number:
        return f"{prefix}:{number}"
    return f"{prefix}:{edition}:{number}"


def normalize_card_number(value: str) -> str:
    normalized = value.strip().upper().lstrip("#")
    if "/" in normalized:
        normalized = normalized.split("/", 1)[0]
    if normalized.isdigit():
        return str(int(normalized))
    match = re.fullmatch(r"([A-Z-]*?)(\d+)([A-Z-]*)", normalized)
    if match:
        prefix, number, suffix = match.groups()
        return f"{prefix}{int(number)}{suffix}"
    return normalized


def upsert_rows(rows: list[dict], batch_size: int = DEFAULT_BATCH_SIZE) -> int:
    if not rows:
        return 0
    unique_rows = {row["lookup_code"]: row for row in rows}
    consolidated = list(unique_rows.values())
    count = 0
    for start in range(0, len(consolidated), batch_size):
        batch = consolidated[start : start + batch_size]
        liga.upsert_supabase_rows(batch)
        count += len(batch)
    return count


def safe_price(value):
    price = liga.parse_money(value)
    if price is None or price <= 0 or price > 10_000_000:
        return None
    return round(price, 2)


def clean_card_name(name: str, exact_code: str) -> str:
    cleaned = re.sub(r"\s+", " ", name).strip()
    cleaned = re.sub(
        rf"\s*\([^)]*{re.escape(exact_code)}[^)]*\)\s*$",
        "",
        cleaned,
        flags=re.IGNORECASE,
    ).strip()
    return cleaned or exact_code


def _is_future_release(value: str) -> bool:
    if not value:
        return False
    try:
        release = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    if release.tzinfo is None:
        release = release.replace(tzinfo=timezone.utc)
    return release > datetime.now(timezone.utc)


def main():
    args = parse_args()
    if args.delay < 0:
        raise ValueError("--delay nao pode ser negativo.")
    shard_index = resolve_shard_index(args.shard_index, args.shard_count)
    editions = fetch_editions(args.game, include_future=args.include_future)
    published_count = len(editions)
    if args.missing_only:
        cached_edition_ids = fetch_cached_edition_ids(args.game)
        editions = select_missing_editions(editions, cached_edition_ids)
    selected = select_editions(
        editions,
        requested=args.edition,
        shard_count=args.shard_count,
        shard_index=shard_index,
        priority_count=args.priority_editions,
    )
    if args.limit is not None:
        selected = selected[: max(0, args.limit)]

    print(f"TCG: {GAME_CONFIGS[args.game]['label']}")
    print(f"Edicoes publicadas e ja lancadas: {published_count}")
    if args.missing_only:
        print(f"Edicoes ainda sem carga pelo ID da Liga: {len(editions)}")
    print(f"Shard: {shard_index + 1}/{args.shard_count}")
    print(f"Edicoes selecionadas: {len(selected)}")
    for edition in selected:
        print(
            f"- {edition.acronym} | {edition.name} | "
            f"grupo={edition.group} id={edition.edition_id}"
        )
    if args.dry_run or not selected:
        return

    failures = []
    written = 0
    for index, edition in enumerate(selected, start=1):
        if index > 1:
            time.sleep(args.delay)
        print(f"[{index}/{len(selected)}] Coletando {edition.acronym}")
        try:
            source = liga.fetch_text(edition.source_url)
            resolved_at = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
            rows = parse_edition_cards_page(
                source,
                edition,
                resolved_at=resolved_at,
            )
            written += upsert_rows(rows)
            print(f"  {len(rows)} cartas gravadas.")
        except Exception as error:
            failures.append((edition.acronym, str(error)))
            print(f"  falha: {error}")

    print(f"Supabase atualizado com {written} linhas de {args.game}.")
    if failures:
        for acronym, error in failures:
            print(f"- {acronym}: {error}")
        raise SystemExit(1)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
