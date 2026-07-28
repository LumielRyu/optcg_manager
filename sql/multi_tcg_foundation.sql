-- Fundacao retrocompativel para colecao, decks, vendas e procurados multi-TCG.
-- Os registros existentes pertencem ao modulo One Piece.

alter table public.collection_items
add column if not exists game_slug text not null default 'one-piece';

alter table public.collection_items
add column if not exists catalog_card_id text not null default '';

alter table public.collection_items
add column if not exists variant_id text not null default '';

alter table public.decks
add column if not exists game_slug text not null default 'one-piece';

alter table public.decks
add column if not exists format_slug text not null default 'one-piece-constructed';

alter table public.deck_items
add column if not exists game_slug text not null default 'one-piece';

alter table public.deck_items
add column if not exists catalog_card_id text not null default '';

alter table public.deck_items
add column if not exists variant_id text not null default '';

alter table public.deck_items
add column if not exists deck_zone text not null default 'main';

alter table public.wanted_cards
add column if not exists game_slug text not null default 'one-piece';

alter table public.wanted_cards
add column if not exists catalog_card_id text not null default '';

alter table public.wanted_cards
add column if not exists variant_id text not null default '';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'collection_items_game_slug_check'
  ) then
    alter table public.collection_items
    add constraint collection_items_game_slug_check
    check (
      game_slug in (
        'one-piece',
        'pokemon',
        'digimon',
        'magic',
        'riftbound',
        'yugioh'
      )
    );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'decks_game_slug_check'
  ) then
    alter table public.decks
    add constraint decks_game_slug_check
    check (
      game_slug in (
        'one-piece',
        'pokemon',
        'digimon',
        'magic',
        'riftbound',
        'yugioh'
      )
    );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'deck_items_game_slug_check'
  ) then
    alter table public.deck_items
    add constraint deck_items_game_slug_check
    check (
      game_slug in (
        'one-piece',
        'pokemon',
        'digimon',
        'magic',
        'riftbound',
        'yugioh'
      )
    );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'wanted_cards_game_slug_check'
  ) then
    alter table public.wanted_cards
    add constraint wanted_cards_game_slug_check
    check (
      game_slug in (
        'one-piece',
        'pokemon',
        'digimon',
        'magic',
        'riftbound',
        'yugioh'
      )
    );
  end if;
end $$;

create index if not exists idx_collection_items_user_game_type
on public.collection_items (user_id, game_slug, collection_type, created_at desc);

create index if not exists idx_collection_items_marketplace_game
on public.collection_items (game_slug, sale_status, sale_expires_at desc)
where collection_type = 'forSale' and is_public = true;

create index if not exists idx_decks_user_game
on public.decks (user_id, game_slug, created_at desc);

create index if not exists idx_deck_items_game_card
on public.deck_items (game_slug, card_code);

create index if not exists idx_wanted_cards_game_active
on public.wanted_cards (game_slug, is_active, created_at desc);
