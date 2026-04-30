create table if not exists public.liga_card_price_cache (
  lookup_code text primary key,
  source_url text not null default '',
  card_name text not null default '',
  card_code text not null default '',
  edition_code text not null default '',
  image_url text not null default '',
  minimum_price numeric null,
  average_price numeric null,
  maximum_price numeric null,
  listing_count integer not null default 0,
  lowest_listing jsonb null,
  lowest_store jsonb null,
  used_verified_fallback boolean not null default false,
  note text null,
  resolved_at timestamptz not null default timezone('utc', now())
);

create index if not exists liga_card_price_cache_resolved_at_idx
on public.liga_card_price_cache (resolved_at desc);

alter table public.liga_card_price_cache enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'liga_card_price_cache'
      and policyname = 'Anyone can read liga card price cache'
  ) then
    create policy "Anyone can read liga card price cache"
    on public.liga_card_price_cache
    for select
    using (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'liga_card_price_cache'
      and policyname = 'Authenticated users can insert liga card price cache'
  ) then
    create policy "Authenticated users can insert liga card price cache"
    on public.liga_card_price_cache
    for insert
    with check (auth.uid() is not null);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'liga_card_price_cache'
      and policyname = 'Authenticated users can update liga card price cache'
  ) then
    create policy "Authenticated users can update liga card price cache"
    on public.liga_card_price_cache
    for update
    using (auth.uid() is not null)
    with check (auth.uid() is not null);
  end if;
end $$;
