alter table public.collection_items
add column if not exists sale_price_cents integer;

alter table public.collection_items
add column if not exists sale_contact_info text;

alter table public.collection_items
add column if not exists sale_notes text;
