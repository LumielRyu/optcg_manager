import argparse
import hashlib
import json
import re
import time
import urllib.parse
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

import update_liga_price_cache as liga


EDITIONS_URL = "https://www.ligaonepiece.com.br/?view=cards/edicoes"
ROOT = Path(__file__).resolve().parents[1]
EDITIONS_FALLBACK_PATH = ROOT / "assets" / "liga_one_piece_editions.json"
DEFAULT_CRAWL_DELAY_SECONDS = 30.0
DEFAULT_PRIORITY_EDITIONS = 3
DEFAULT_BATCH_SIZE = 250
CATALOG_TABLE = "one_piece_card_catalog"
KNOWN_VARIANT_SUFFIXES = {
    "AA",
    "DP",
    "FA",
    "G",
    "MA",
    "OP",
    "PA",
    "PR",
    "RE",
    "SP",
    "TR",
}
LIGA_RARITIES = {
    1: "C",
    2: "UC",
    3: "R",
    4: "SR",
    5: "P",
    6: "L",
    7: "SEC",
    8: "DON!!",
    9: "SP",
    10: "TR",
}
LIGA_COLORS = {
    1: "Red",
    2: "Purple",
    3: "Green",
    4: "Blue",
    5: "Black",
    6: "Yellow",
    7: "Multi Colored",
}


@dataclass(frozen=True)
class LigaEdition:
    edition_id: int
    acronym: str
    name: str
    release_date: str
    group: str

    @property
    def source_url(self) -> str:
        query = urllib.parse.urlencode(
            {
                "view": "cards/search",
                "card": f"edid={self.edition_id} ed={self.acronym}",
            }
        )
        return f"https://www.ligaonepiece.com.br/?{query}"


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Atualiza o cache da LigaOnePiece por edicao. Cada pagina de "
            "edicao fornece todas as cartas e variantes em um unico JSON."
        )
    )
    parser.add_argument(
        "--edition",
        action="append",
        default=[],
        help="Atualiza somente a sigla informada. Pode ser repetido.",
    )
    parser.add_argument(
        "--shard-count",
        type=int,
        default=1,
        help="Quantidade de grupos usados para dividir as edicoes antigas.",
    )
    parser.add_argument(
        "--shard-index",
        type=int,
        default=0,
        help="Indice do grupo desta execucao, iniciando em zero.",
    )
    parser.add_argument(
        "--priority-editions",
        type=int,
        default=DEFAULT_PRIORITY_EDITIONS,
        help="Edicoes mais recentes atualizadas em todas as execucoes.",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=DEFAULT_CRAWL_DELAY_SECONDS,
        help="Intervalo em segundos entre requisicoes publicas.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        help="Limita edicoes para diagnostico.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Lista as edicoes selecionadas sem consultar ou gravar precos.",
    )
    return parser.parse_args()


def parse_editions_page(source: str) -> list[LigaEdition]:
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
            group_items = [
                item
                for nested in group_payload.values()
                if isinstance(nested, list)
                for item in nested
            ]
        elif isinstance(group_payload, list):
            group_items = group_payload
        else:
            group_items = []

        for item in group_items:
            if not isinstance(item, dict):
                continue
            acronym = str(item.get("acronym") or "").strip().upper()
            try:
                edition_id = int(item.get("id") or 0)
            except (TypeError, ValueError):
                edition_id = 0
            if not acronym or edition_id <= 0 or edition_id in seen:
                continue
            seen.add(edition_id)
            editions.append(
                LigaEdition(
                    edition_id=edition_id,
                    acronym=acronym,
                    name=str(
                        item.get("namept")
                        or item.get("nameen")
                        or item.get("name")
                        or acronym
                    ).strip(),
                    release_date=str(item.get("dtrelease") or "").strip(),
                    group=group,
                )
            )

    editions.sort(
        key=lambda edition: (edition.release_date, edition.edition_id),
        reverse=True,
    )
    return editions


def load_fallback_editions(
    path: Path = EDITIONS_FALLBACK_PATH,
) -> list[LigaEdition]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(
            f"Catalogo local de edicoes indisponivel: {path}."
        ) from error

    editions = []
    for item in payload:
        if not isinstance(item, dict):
            continue
        try:
            edition_id = int(item.get("edition_id") or 0)
        except (TypeError, ValueError):
            edition_id = 0
        acronym = str(item.get("acronym") or "").strip().upper()
        if edition_id <= 0 or not acronym:
            continue
        editions.append(
            LigaEdition(
                edition_id=edition_id,
                acronym=acronym,
                name=str(item.get("name") or acronym).strip(),
                release_date=str(item.get("release_date") or "").strip(),
                group=str(item.get("group") or "main").strip(),
            )
        )

    editions.sort(
        key=lambda edition: (edition.release_date, edition.edition_id),
        reverse=True,
    )
    if not editions:
        raise RuntimeError("Catalogo local de edicoes esta vazio.")
    return editions


def discover_editions(
    requested: list[str],
    *,
    fallback_path: Path = EDITIONS_FALLBACK_PATH,
) -> tuple[list[LigaEdition], str, bool]:
    fallback = load_fallback_editions(fallback_path)
    normalized_requested = {
        value.strip().upper() for value in requested if value.strip()
    }
    if normalized_requested and normalized_requested.issubset(
        {edition.acronym for edition in fallback}
    ):
        return fallback, "catalogo local versionado", False

    try:
        source = liga.fetch_text(EDITIONS_URL)
        return parse_editions_page(source), "pagina publica de edicoes", True
    except (RuntimeError, urllib.error.URLError) as error:
        print(
            "Aviso: pagina de edicoes indisponivel; usando catalogo local "
            f"versionado ({error})."
        )
        return fallback, "catalogo local versionado", True


def select_editions(
    editions: list[LigaEdition],
    *,
    requested: list[str],
    shard_count: int,
    shard_index: int,
    priority_count: int,
) -> list[LigaEdition]:
    if shard_count <= 0:
        raise ValueError("--shard-count precisa ser maior que zero.")
    if shard_index < 0 or shard_index >= shard_count:
        raise ValueError("--shard-index precisa pertencer ao intervalo dos grupos.")

    normalized_requested = {
        value.strip().upper() for value in requested if value.strip()
    }
    if normalized_requested:
        selected = [
            edition
            for edition in editions
            if edition.acronym in normalized_requested
        ]
        missing = normalized_requested - {edition.acronym for edition in selected}
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
    edition: LigaEdition,
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
        exact_code = liga.normalize_code(str(item.get("sN") or ""))
        if not exact_code or exact_code in seen:
            continue

        minimum = _safe_price(item.get("precoMenor") or item.get("p1a"))
        average = _safe_price(item.get("p1b"))
        maximum = _safe_price(item.get("precoMaior") or item.get("p1c"))

        seen.add(exact_code)
        row = {
                "lookup_code": storage_lookup_code(exact_code, edition),
                "source_url": edition.source_url,
                "card_name": _clean_card_name(
                    str(item.get("nPT") or item.get("nEN") or exact_code),
                    exact_code,
                ),
                "card_code": exact_code,
                "edition_code": edition.acronym,
                "image_url": liga.normalize_asset_url(
                    str(item.get("sP") or "").strip()
                ),
                "minimum_price": minimum,
                "average_price": average,
                "maximum_price": maximum,
                "used_verified_fallback": False,
                "note": (
                    "Coletado em lote da pagina publica da edicao "
                    f"{edition.acronym} (Liga ID {edition.edition_id})."
                ),
                "resolved_at": resolved_at,
            }
        rows.append(row)
        scoped_lookup = edition_scoped_lookup_code(exact_code, edition)
        if scoped_lookup != row["lookup_code"]:
            rows.append({**row, "lookup_code": scoped_lookup})
    return rows


def parse_catalog_cards_page(
    source: str,
    edition: LigaEdition,
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
        exact_code = liga.normalize_code(str(item.get("sN") or ""))
        image_url = liga.normalize_asset_url(str(item.get("sP") or "").strip())
        if not exact_code or not image_url:
            continue

        try:
            source_card_id = int(item.get("id") or 0)
        except (TypeError, ValueError):
            source_card_id = 0
        source_identity = str(source_card_id) if source_card_id > 0 else hashlib.sha256(
            image_url.encode("utf-8")
        ).hexdigest()[:20]
        catalog_key = f"liga:{edition.edition_id}:{source_identity}"
        if catalog_key in seen:
            continue
        seen.add(catalog_key)

        source_metadata = {
            key: item.get(key)
            for key in (
                "dN",
                "dt",
                "iCMC",
                "iCO",
                "iR",
                "iT",
                "idNC",
                "pF",
                "sA",
                "sC",
                "sT",
            )
            if item.get(key) is not None and item.get(key) != ""
        }
        rows.append(
            {
                "catalog_key": catalog_key,
                "source": "liga",
                "source_card_id": source_card_id or None,
                "source_url": edition.source_url,
                "edition_id": edition.edition_id,
                "edition_code": edition.acronym,
                "edition_name": edition.name,
                "edition_group": edition.group,
                "release_date": edition.release_date or None,
                "card_code": exact_code,
                "card_name": _clean_card_name(
                    str(item.get("nPT") or item.get("nEN") or exact_code),
                    exact_code,
                ),
                "image_url": image_url,
                "rarity": _catalog_label(LIGA_RARITIES, item.get("iR")),
                "color": _catalog_label(LIGA_COLORS, item.get("sC")),
                "source_metadata": source_metadata,
                "published_at": str(item.get("dt") or "").strip() or None,
                "resolved_at": resolved_at,
            }
        )
    return rows


def storage_lookup_code(exact_code: str, edition: LigaEdition) -> str:
    normalized_code = liga.normalize_code(exact_code)
    if edition.group != "aux":
        return normalized_code
    return f"{normalized_code}@{edition.acronym}"


def edition_scoped_lookup_code(exact_code: str, edition: LigaEdition) -> str:
    normalized_code = liga.normalize_code(exact_code)
    return f"{normalized_code}@{edition.acronym}"


def upsert_rows(rows: list[dict], batch_size: int = DEFAULT_BATCH_SIZE) -> int:
    if not rows:
        return 0
    if batch_size <= 0:
        raise ValueError("batch_size precisa ser maior que zero.")

    unique_rows = {}
    for row in rows:
        lookup_code = liga.normalize_code(str(row.get("lookup_code") or ""))
        if lookup_code and lookup_code not in unique_rows:
            unique_rows[lookup_code] = row

    consolidated = list(unique_rows.values())
    count = 0
    for start in range(0, len(consolidated), batch_size):
        batch = consolidated[start : start + batch_size]
        liga.upsert_supabase_rows(batch)
        count += len(batch)
    return count


def upsert_catalog_rows(
    rows: list[dict], batch_size: int = DEFAULT_BATCH_SIZE
) -> int:
    if not rows:
        return 0
    if batch_size <= 0:
        raise ValueError("batch_size precisa ser maior que zero.")

    env = liga.load_env()
    supabase_url = (env.get("SUPABASE_URL") or "").rstrip("/")
    service_key = env.get("SUPABASE_SERVICE_ROLE_KEY") or ""
    if not supabase_url or not service_key:
        raise RuntimeError(
            "SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY precisam existir no .env."
        )

    unique_rows = {
        str(row.get("catalog_key") or "").strip(): row
        for row in rows
        if str(row.get("catalog_key") or "").strip()
    }
    consolidated = list(unique_rows.values())
    count = 0
    for start in range(0, len(consolidated), batch_size):
        batch = consolidated[start : start + batch_size]
        url = (
            f"{supabase_url}/rest/v1/{CATALOG_TABLE}?"
            "on_conflict=catalog_key"
        )
        request = urllib.request.Request(
            url,
            data=json.dumps(batch, ensure_ascii=False).encode("utf-8"),
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
        count += len(batch)
    return count


def base_card_code(exact_code: str) -> str:
    normalized = liga.normalize_code(exact_code)
    suffix = normalized.rsplit("-", 1)[-1]
    if suffix in KNOWN_VARIANT_SUFFIXES:
        return normalized.rsplit("-", 1)[0]
    return normalized


def _safe_price(value):
    price = liga.parse_money(value)
    if price is None or price <= 0 or price > 10_000_000:
        return None
    return round(price, 2)


def _catalog_label(labels: dict[int, str], value) -> str:
    try:
        normalized = int(value)
    except (TypeError, ValueError):
        return ""
    return labels.get(normalized, "")


def _clean_card_name(name: str, exact_code: str) -> str:
    cleaned = re.sub(r"\s+", " ", name).strip()
    cleaned = re.sub(
        rf"\s*\({re.escape(exact_code)}\)\s*$",
        "",
        cleaned,
        flags=re.IGNORECASE,
    ).strip()
    return cleaned or exact_code


def main():
    args = parse_args()
    if args.delay < 0:
        raise ValueError("--delay nao pode ser negativo.")

    editions, catalog_source, catalog_request_attempted = discover_editions(
        args.edition
    )
    selected = select_editions(
        editions,
        requested=args.edition,
        shard_count=args.shard_count,
        shard_index=args.shard_index,
        priority_count=args.priority_editions,
    )
    if args.limit is not None:
        selected = selected[: max(0, args.limit)]

    print(f"Edicoes publicadas pela Liga: {len(editions)}")
    print(f"Origem do catalogo de edicoes: {catalog_source}")
    print(f"Edicoes selecionadas nesta execucao: {len(selected)}")
    for edition in selected:
        print(
            f"- {edition.acronym} | {edition.name} | "
            f"grupo={edition.group} id={edition.edition_id}"
        )
    if args.dry_run or not selected:
        return

    all_rows = []
    all_catalog_rows = []
    failures = []
    for index, edition in enumerate(selected, start=1):
        if index > 1 or catalog_request_attempted:
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
            catalog_rows = parse_catalog_cards_page(
                source,
                edition,
                resolved_at=resolved_at,
            )
            if not rows:
                print("  nenhuma carta publicada; edicao ignorada.")
                continue
            all_rows.extend(rows)
            all_catalog_rows.extend(catalog_rows)
            print(f"  {len(rows)} cartas e variantes preparadas.")
        except Exception as error:
            failures.append((edition.acronym, str(error)))
            print(f"  falha: {error}")

    written = upsert_rows(all_rows)
    print(f"Supabase atualizado com {written} linhas.")
    try:
        catalog_written = upsert_catalog_rows(all_catalog_rows)
        print(f"Catalogo proprio atualizado com {catalog_written} variantes.")
    except Exception as error:
        print(
            "Aviso: cache de precos atualizado, mas o catalogo proprio nao "
            f"pode ser gravado ({error})."
        )
    if failures:
        print(f"Edicoes com falha: {len(failures)}")
        for acronym, error in failures:
            print(f"- {acronym}: {error}")
        raise SystemExit(1)


if __name__ == "__main__":
    main()
