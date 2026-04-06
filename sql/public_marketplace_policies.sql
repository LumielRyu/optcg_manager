alter table public.collection_items enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'collection_items'
      and policyname = 'Public can read public marketplace listings'
  ) then
    create policy "Public can read public marketplace listings"
    on public.collection_items
    for select
    using (
      collection_type = 'forSale'
      and is_public = true
    );
  end if;
end $$;
