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
    and exists (
      select 1
      from public.collection_items ci
      where ci.user_id = p.id
        and ci.collection_type = 'forSale'
        and ci.is_public = true
    );
$$;

revoke all on function public.get_public_seller_profiles(uuid[]) from public;
grant execute on function public.get_public_seller_profiles(uuid[]) to anon;
grant execute on function public.get_public_seller_profiles(uuid[]) to authenticated;
