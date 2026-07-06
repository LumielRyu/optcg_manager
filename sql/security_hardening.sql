-- Security hardening for public Data API access and user-owned data.
-- Run this in Supabase SQL Editor after review.

alter table public.profiles enable row level security;
alter table public.collection_items enable row level security;
alter table public.decks enable row level security;
alter table public.deck_items enable row level security;
alter table public.wanted_cards enable row level security;

grant select, insert, update, delete on public.collection_items to authenticated;
grant select, insert, update, delete on public.decks to authenticated;
grant select, insert, update, delete on public.deck_items to authenticated;
grant select on public.collection_items, public.decks, public.deck_items to anon;

drop policy if exists "Users can read own collection items" on public.collection_items;
create policy "Users can read own collection items"
on public.collection_items for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own collection items" on public.collection_items;
create policy "Users can insert own collection items"
on public.collection_items for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own collection items" on public.collection_items;
create policy "Users can update own collection items"
on public.collection_items for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete own collection items" on public.collection_items;
create policy "Users can delete own collection items"
on public.collection_items for delete to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Public can read public marketplace listings" on public.collection_items;
create policy "Public can read public marketplace listings"
on public.collection_items for select to anon, authenticated
using (
  collection_type = 'forSale'
  and is_public = true
  and sale_status = 'active'
  and sale_expires_at is not null
  and sale_expires_at > now()
);

drop policy if exists "Users can read own decks" on public.decks;
create policy "Users can read own decks"
on public.decks for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert own decks" on public.decks;
create policy "Users can insert own decks"
on public.decks for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update own decks" on public.decks;
create policy "Users can update own decks"
on public.decks for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete own decks" on public.decks;
create policy "Users can delete own decks"
on public.decks for delete to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Public can read shared decks" on public.decks;
create policy "Public can read shared decks"
on public.decks for select to anon, authenticated
using (is_public = true and share_code is not null);

drop policy if exists "Users can read own deck items" on public.deck_items;
create policy "Users can read own deck items"
on public.deck_items for select to authenticated
using (
  exists (
    select 1
    from public.decks d
    where d.id = deck_id
      and d.user_id = (select auth.uid())
  )
);

drop policy if exists "Users can insert own deck items" on public.deck_items;
create policy "Users can insert own deck items"
on public.deck_items for insert to authenticated
with check (
  exists (
    select 1
    from public.decks d
    where d.id = deck_id
      and d.user_id = (select auth.uid())
  )
);

drop policy if exists "Users can update own deck items" on public.deck_items;
create policy "Users can update own deck items"
on public.deck_items for update to authenticated
using (
  exists (
    select 1
    from public.decks d
    where d.id = deck_id
      and d.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1
    from public.decks d
    where d.id = deck_id
      and d.user_id = (select auth.uid())
  )
);

drop policy if exists "Users can delete own deck items" on public.deck_items;
create policy "Users can delete own deck items"
on public.deck_items for delete to authenticated
using (
  exists (
    select 1
    from public.decks d
    where d.id = deck_id
      and d.user_id = (select auth.uid())
  )
);

drop policy if exists "Public can read shared deck items" on public.deck_items;
create policy "Public can read shared deck items"
on public.deck_items for select to anon, authenticated
using (
  exists (
    select 1
    from public.decks d
    where d.id = deck_id
      and d.is_public = true
      and d.share_code is not null
  )
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

create or replace function public.get_public_wanted_card_contact(wanted_card_id uuid)
returns text
language sql
security definer
set search_path = public, pg_temp
as $$
  select coalesce(wc.contact_info, '')
  from public.wanted_cards wc
  where (select auth.uid()) is not null
    and wc.id = wanted_card_id
    and wc.is_public = true
    and wc.is_active = true
  limit 1;
$$;

revoke all on function public.get_public_marketplace_listing_contact(uuid) from public;
revoke all on function public.get_public_wanted_card_contact(uuid) from public;
grant execute on function public.get_public_marketplace_listing_contact(uuid) to authenticated;
grant execute on function public.get_public_wanted_card_contact(uuid) to authenticated;
