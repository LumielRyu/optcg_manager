alter table public.collection_items
add column if not exists sale_expires_at timestamptz;

create index if not exists idx_collection_items_public_for_sale_expires_at
on public.collection_items (sale_expires_at desc, created_at desc)
where collection_type = 'forSale'
  and is_public = true
  and sale_status = 'active';

update public.collection_items
set is_public = false
where collection_type = 'forSale'
  and is_public = true;

drop policy if exists "Public can read public marketplace listings" on public.collection_items;
create policy "Public can read public marketplace listings"
on public.collection_items
for select
to anon, authenticated
using (
  collection_type = 'forSale'
  and is_public = true
  and sale_status = 'active'
  and sale_expires_at is not null
  and sale_expires_at > now()
);

create or replace function public.get_public_marketplace_listing_contact(listing_id uuid)
returns text
language sql
security definer
set search_path = public, pg_temp
as $$
  select coalesce(ci.sale_contact_info, '')
  from public.collection_items ci
  where (select auth.uid()) is not null
    and ci.id = listing_id
    and ci.collection_type = 'forSale'
    and ci.is_public = true
    and ci.sale_status = 'active'
    and ci.sale_expires_at is not null
    and ci.sale_expires_at > now()
  limit 1;
$$;

revoke all on function public.get_public_marketplace_listing_contact(uuid) from public;
grant execute on function public.get_public_marketplace_listing_contact(uuid) to authenticated;
