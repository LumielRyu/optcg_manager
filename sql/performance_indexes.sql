create index if not exists idx_collection_items_user_type_created_at
on public.collection_items (user_id, collection_type, created_at desc);

create index if not exists idx_collection_items_public_for_sale_created_at
on public.collection_items (user_id, created_at desc)
where collection_type = 'forSale' and is_public = true;

create index if not exists idx_collection_items_share_code_public
on public.collection_items (share_code)
where collection_type = 'forSale' and is_public = true;

create index if not exists idx_collection_items_card_code_type
on public.collection_items (card_code, collection_type);

create index if not exists idx_decks_user_name
on public.decks (user_id, name);

create index if not exists idx_deck_items_deck_id
on public.deck_items (deck_id);
