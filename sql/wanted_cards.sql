create extension if not exists pgcrypto;

create table if not exists public.wanted_cards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  card_code text not null,
  quantity integer not null default 1 check (quantity > 0),
  is_public boolean not null default true,
  is_active boolean not null default true,
  contact_info text,
  notes text,
  image_url text,
  name text,
  set_name text,
  rarity text,
  color text,
  type text,
  text text,
  attribute text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists wanted_cards_public_active_created_idx
on public.wanted_cards (is_public, is_active, created_at desc);

create index if not exists wanted_cards_user_created_idx
on public.wanted_cards (user_id, created_at desc);

create index if not exists wanted_cards_card_code_idx
on public.wanted_cards (card_code);

alter table public.wanted_cards enable row level security;

grant select on public.wanted_cards to anon;
grant select, insert, update, delete on public.wanted_cards to authenticated;
grant select, insert, update, delete on public.wanted_cards to service_role;

create or replace function public.get_public_seller_profiles(user_ids uuid[])
returns table (
  id uuid,
  name text
)
language sql
security definer
set search_path = public, pg_temp
as $$
  select p.id, coalesce(p.name, '') as name
  from public.profiles p
  where p.id = any(user_ids)
    and (
      exists (
        select 1
        from public.collection_items ci
        where ci.user_id = p.id
          and ci.collection_type = 'forSale'
          and ci.is_public = true
      )
      or exists (
        select 1
        from public.wanted_cards wc
        where wc.user_id = p.id
          and wc.is_public = true
          and wc.is_active = true
      )
    );
$$;

revoke all on function public.get_public_seller_profiles(uuid[]) from public;
grant execute on function public.get_public_seller_profiles(uuid[]) to anon;
grant execute on function public.get_public_seller_profiles(uuid[]) to authenticated;
grant execute on function public.get_public_seller_profiles(uuid[]) to service_role;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'wanted_cards'
      and policyname = 'Public can read active wanted cards'
  ) then
    create policy "Public can read active wanted cards"
    on public.wanted_cards
    for select
    using (is_public = true and is_active = true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'wanted_cards'
      and policyname = 'Users can read own wanted cards'
  ) then
    create policy "Users can read own wanted cards"
    on public.wanted_cards
    for select
    to authenticated
    using ((select auth.uid()) = user_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'wanted_cards'
      and policyname = 'Users can insert own wanted cards'
  ) then
    create policy "Users can insert own wanted cards"
    on public.wanted_cards
    for insert
    to authenticated
    with check ((select auth.uid()) = user_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'wanted_cards'
      and policyname = 'Users can update own wanted cards'
  ) then
    create policy "Users can update own wanted cards"
    on public.wanted_cards
    for update
    to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'wanted_cards'
      and policyname = 'Users can delete own wanted cards'
  ) then
    create policy "Users can delete own wanted cards"
    on public.wanted_cards
    for delete
    to authenticated
    using ((select auth.uid()) = user_id);
  end if;
end $$;
