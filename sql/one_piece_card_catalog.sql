create table if not exists public.one_piece_card_catalog (
  catalog_key text primary key,
  source text not null default 'liga',
  source_card_id integer null,
  source_url text not null default '',
  edition_id integer not null,
  edition_code text not null,
  edition_name text not null default '',
  edition_group text not null default 'main',
  release_date timestamptz null,
  card_code text not null,
  card_name text not null,
  image_url text not null,
  rarity text not null default '',
  color text not null default '',
  card_type text not null default '',
  sub_types text not null default '',
  card_text text not null default '',
  attribute text not null default '',
  source_metadata jsonb not null default '{}'::jsonb,
  published_at timestamptz null,
  resolved_at timestamptz not null default timezone('utc', now()),
  constraint one_piece_card_catalog_source_check
    check (source in ('liga', 'official', 'manual')),
  constraint one_piece_card_catalog_group_check
    check (edition_group in ('main', 'aux'))
);

create index if not exists one_piece_card_catalog_edition_idx
  on public.one_piece_card_catalog (edition_code, card_code);

create index if not exists one_piece_card_catalog_card_code_idx
  on public.one_piece_card_catalog (card_code);

create index if not exists one_piece_card_catalog_resolved_at_idx
  on public.one_piece_card_catalog (resolved_at desc);

alter table public.one_piece_card_catalog enable row level security;

revoke insert, update, delete, truncate, references, trigger
  on public.one_piece_card_catalog
  from anon, authenticated;

grant select
  on public.one_piece_card_catalog
  to anon, authenticated;

drop policy if exists "Anyone can read One Piece card catalog"
  on public.one_piece_card_catalog;

create policy "Anyone can read One Piece card catalog"
  on public.one_piece_card_catalog
  for select
  using (true);

comment on table public.one_piece_card_catalog is
  'Catalogo proprio do TCG BH para cartas e variantes de One Piece.';
