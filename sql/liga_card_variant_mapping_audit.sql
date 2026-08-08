-- Correspondencias persistentes entre cada impressao do catalogo e a Liga.
-- Esta estrutura permite confirmar manualmente casos em que codigo e nome nao
-- bastam para distinguir Manga, Treasure Cup, Winner e outras variantes.

create table if not exists public.liga_card_variant_mappings (
  id uuid primary key default gen_random_uuid(),
  game_slug text not null default 'one-piece',
  catalog_variant_key text not null,
  catalog_card_code text not null,
  catalog_card_name text not null,
  catalog_set_name text,
  catalog_image_url text,
  variant_kind text not null,
  liga_lookup_code text,
  liga_edition_code text,
  liga_image_url text,
  confidence numeric(5, 4) not null default 0,
  match_method text not null default 'missing',
  status text not null default 'missing',
  is_manual boolean not null default false,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (game_slug, catalog_variant_key),
  constraint liga_variant_mapping_confidence_check
    check (confidence between 0 and 1),
  constraint liga_variant_mapping_method_check
    check (match_method in (
      'exact_metadata', 'exact_image', 'perceptual_image', 'manual',
      'ambiguous', 'missing'
    )),
  constraint liga_variant_mapping_status_check
    check (status in ('confirmed', 'review', 'missing', 'rejected'))
);

create index if not exists liga_variant_mapping_status_idx
  on public.liga_card_variant_mappings (game_slug, status, variant_kind);
create index if not exists liga_variant_mapping_card_idx
  on public.liga_card_variant_mappings (game_slug, catalog_card_code);
create index if not exists liga_variant_mapping_liga_idx
  on public.liga_card_variant_mappings (game_slug, liga_lookup_code);

create table if not exists public.liga_price_audit_runs (
  id uuid primary key default gen_random_uuid(),
  game_slug text not null default 'one-piece',
  status text not null default 'running',
  catalog_card_count integer not null default 0,
  uniquely_matched_count integer not null default 0,
  ambiguous_count integer not null default 0,
  missing_count integer not null default 0,
  details jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint liga_price_audit_run_status_check
    check (status in ('running', 'completed', 'failed'))
);

create index if not exists liga_price_audit_runs_game_started_idx
  on public.liga_price_audit_runs (game_slug, started_at desc);

alter table public.liga_card_variant_mappings enable row level security;
alter table public.liga_price_audit_runs enable row level security;

revoke all on public.liga_card_variant_mappings from anon, authenticated;
revoke all on public.liga_price_audit_runs from anon, authenticated;
grant select on public.liga_card_variant_mappings to authenticated;
grant select on public.liga_price_audit_runs to authenticated;

drop policy if exists "Authenticated users read Liga variant mappings"
  on public.liga_card_variant_mappings;
create policy "Authenticated users read Liga variant mappings"
  on public.liga_card_variant_mappings
  for select
  to authenticated
  using (true);

drop policy if exists "Authenticated users read Liga audit runs"
  on public.liga_price_audit_runs;
create policy "Authenticated users read Liga audit runs"
  on public.liga_price_audit_runs
  for select
  to authenticated
  using (true);

comment on table public.liga_card_variant_mappings is
  'Pareamento auditavel entre impressoes do catalogo e registros de preco da Liga.';
comment on table public.liga_price_audit_runs is
  'Historico resumido das auditorias de correspondencia de variantes e precos.';
