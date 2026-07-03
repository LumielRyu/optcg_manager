alter table public.collection_items
add column if not exists sale_pricing_mode text not null default 'manual';

alter table public.collection_items
add column if not exists sale_liga_percentage numeric(7, 2);

alter table public.collection_items
add column if not exists sale_liga_rounding text not null default 'none';

alter table public.collection_items
add column if not exists sale_liga_base_price_cents integer;

alter table public.collection_items
add column if not exists sale_liga_price_updated_at timestamptz;

alter table public.collection_items
add column if not exists sale_liga_price_source text;

alter table public.collection_items
drop constraint if exists collection_items_sale_pricing_mode_check;

alter table public.collection_items
add constraint collection_items_sale_pricing_mode_check
check (sale_pricing_mode in ('manual', 'liga_percentage'));

alter table public.collection_items
drop constraint if exists collection_items_sale_liga_rounding_check;

alter table public.collection_items
add constraint collection_items_sale_liga_rounding_check
check (sale_liga_rounding in ('none', 'up', 'down'));
