import argparse
import json
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone

import update_liga_price_cache as liga


DEFAULT_REFRESH_DAYS = 7


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Atualiza automaticamente o cache da LigaOnePiece para cartas "
            "ativas na area de vendas."
        )
    )
    parser.add_argument("--limit", type=int, help="Limita a quantidade de cartas.")
    parser.add_argument(
        "--refresh-days",
        type=int,
        default=DEFAULT_REFRESH_DAYS,
        help="Reconsulta cartas com cache mais antigo que N dias.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Mostra o que seria atualizado sem gravar no Supabase.",
    )
    parser.add_argument(
        "--sleep",
        type=float,
        default=0.35,
        help="Pausa entre consultas na LigaOnePiece.",
    )
    parser.add_argument(
        "--public-only",
        action="store_true",
        help="Atualiza apenas cartas publicas no marketplace.",
    )
    parser.add_argument("--code", help="Atualiza uma carta especifica pelo codigo.")
    parser.add_argument("--name", help="Nome da carta ao usar --code.")
    return parser.parse_args()


def supabase_request(path: str, *, method="GET", payload=None):
    env = liga.load_env()
    supabase_url = (env.get("SUPABASE_URL") or "").rstrip("/")
    service_key = env.get("SUPABASE_SERVICE_ROLE_KEY") or ""
    if not supabase_url or not service_key:
        raise RuntimeError(
            "SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY precisam existir no .env."
        )

    data = None
    headers = {
        "apikey": service_key,
        "authorization": f"Bearer {service_key}",
        "accept": "application/json",
    }
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["content-type"] = "application/json"

    request = urllib.request.Request(
        f"{supabase_url}{path}",
        method=method,
        headers=headers,
        data=data,
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        body = response.read().decode("utf-8")
        return json.loads(body) if body else None


def load_marketplace_cards(limit: int | None, *, public_only: bool):
    params = {
        "select": "card_code,name,created_at",
        "collection_type": "eq.forSale",
        "sale_status": "eq.active",
        "order": "created_at.desc",
    }
    if public_only:
        params["is_public"] = "eq.true"
    if limit is not None:
        params["limit"] = str(limit)

    query = urllib.parse.urlencode(params)
    rows = supabase_request(f"/rest/v1/collection_items?{query}") or []
    cards = {}
    for row in rows:
        code = liga.normalize_code(str(row.get("card_code") or ""))
        name = str(row.get("name") or code).strip()
        if not code:
            continue
        cards.setdefault(code, name)
    return [{"code": code, "name": name} for code, name in cards.items()]


def load_existing_cache(codes: list[str]):
    if not codes:
        return {}

    existing = {}
    for chunk_start in range(0, len(codes), 80):
        chunk = codes[chunk_start : chunk_start + 80]
        encoded_codes = ",".join(chunk)
        query = (
            "/rest/v1/liga_card_price_cache?"
            "select=lookup_code,resolved_at,minimum_price"
            f"&lookup_code=in.({encoded_codes})"
        )
        rows = supabase_request(query) or []
        for row in rows:
            code = liga.normalize_code(str(row.get("lookup_code") or ""))
            if code:
                existing[code] = row
    return existing


def is_stale(row, refresh_days: int):
    if row is None:
        return True
    raw = str(row.get("resolved_at") or "").strip()
    if not raw:
        return True
    try:
        resolved_at = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return True
    age = datetime.now(timezone.utc) - resolved_at.astimezone(timezone.utc)
    return age.days >= refresh_days


def main():
    args = parse_args()
    if args.code:
        code = liga.normalize_code(args.code)
        if not code:
            raise RuntimeError("--code invalido.")
        cards = [{"code": code, "name": (args.name or code).strip()}]
    else:
        cards = load_marketplace_cards(args.limit, public_only=args.public_only)
    existing = load_existing_cache([card["code"] for card in cards])
    targets = [
        card
        for card in cards
        if is_stale(existing.get(card["code"]), args.refresh_days)
    ]

    scope_label = "publicas ativas no marketplace" if args.public_only else "ativas em vendas"
    print(f"Cartas {scope_label}: {len(cards)}")
    print(f"Cartas que precisam atualizar cache: {len(targets)}")
    if args.dry_run:
        for card in targets:
            print(f"- {card['code']} {card['name']}")
        return

    resolved = []
    failures = []
    for index, card in enumerate(targets, start=1):
        code = card["code"]
        name = card["name"]
        print(f"[{index}/{len(targets)}] {code} {name}")
        snapshot = liga.fetch_snapshot_for_card(name, code)
        if snapshot is None:
            failures.append(card)
            print(f"  nao resolvida")
        else:
            resolved.append(snapshot)
            print(f"  menor preco: {snapshot.get('minimumPrice')}")
        time.sleep(max(0, args.sleep))

    if resolved:
        count = liga.upsert_supabase_snapshots(resolved)
        print(f"Supabase atualizado com {count} cartas.")
    if failures:
        print(f"Falhas: {len(failures)}")
        for card in failures:
            print(f"- {card['code']} {card['name']}")


if __name__ == "__main__":
    main()
