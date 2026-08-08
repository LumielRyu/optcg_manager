-- Reservas transacionais do marketplace.
-- O estoque e reduzido no momento da reserva e restaurado automaticamente
-- se o vendedor nao confirmar o pedido em ate 24 horas.

create extension if not exists pgcrypto;
create extension if not exists pg_cron;

create table if not exists public.marketplace_orders (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid references auth.users(id) on delete set null,
  buyer_id uuid references auth.users(id) on delete set null,
  status text not null default 'pending',
  buyer_name text not null default '',
  buyer_contact text not null default '',
  seller_name text not null default '',
  seller_contact text not null default '',
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  confirmed_at timestamptz,
  resolved_at timestamptz,
  constraint marketplace_orders_different_users_check
    check (seller_id <> buyer_id),
  constraint marketplace_orders_status_check
    check (status in ('pending', 'confirmed', 'cancelled', 'expired')),
  constraint marketplace_orders_expiration_check
    check (expires_at > created_at)
);

create table if not exists public.marketplace_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.marketplace_orders(id)
    on delete cascade,
  listing_id uuid references public.collection_items(id)
    on delete set null,
  quantity integer not null,
  unit_price_cents integer,
  game_slug text not null default 'one-piece',
  card_code text not null default '',
  card_name text not null default '',
  image_url text not null default '',
  card_condition text not null default 'mint',
  created_at timestamptz not null default now(),
  constraint marketplace_order_items_quantity_check check (quantity > 0),
  constraint marketplace_order_items_price_check
    check (unit_price_cents is null or unit_price_cents >= 0),
  constraint marketplace_order_items_unique_listing unique (order_id, listing_id)
);

create index if not exists idx_marketplace_orders_seller_pending
on public.marketplace_orders (seller_id, expires_at)
where status = 'pending';

create index if not exists idx_marketplace_orders_buyer_created
on public.marketplace_orders (buyer_id, created_at desc);

create index if not exists idx_marketplace_order_items_order
on public.marketplace_order_items (order_id, created_at);

alter table public.marketplace_orders enable row level security;
alter table public.marketplace_order_items enable row level security;

create or replace function public.prevent_pending_marketplace_listing_delete()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if exists (
    select 1
    from public.marketplace_order_items items
    join public.marketplace_orders orders on orders.id = items.order_id
    where items.listing_id = old.id
      and orders.status = 'pending'
  ) then
    raise exception 'Este anuncio possui uma reserva pendente e ainda nao pode ser excluido.';
  end if;

  return old;
end;
$$;

drop trigger if exists prevent_pending_marketplace_listing_delete
on public.collection_items;
create trigger prevent_pending_marketplace_listing_delete
before delete on public.collection_items
for each row execute function public.prevent_pending_marketplace_listing_delete();

revoke all on table public.marketplace_orders from anon, authenticated;
revoke all on table public.marketplace_order_items from anon, authenticated;
grant select on table public.marketplace_orders to authenticated;
grant select on table public.marketplace_order_items to authenticated;

drop policy if exists "Participants can read marketplace orders"
on public.marketplace_orders;
create policy "Participants can read marketplace orders"
on public.marketplace_orders for select to authenticated
using ((select auth.uid()) in (seller_id, buyer_id));

drop policy if exists "Participants can read marketplace order items"
on public.marketplace_order_items;
create policy "Participants can read marketplace order items"
on public.marketplace_order_items for select to authenticated
using (
  exists (
    select 1
    from public.marketplace_orders orders
    where orders.id = order_id
      and (select auth.uid()) in (orders.seller_id, orders.buyer_id)
  )
);

create or replace function public.expire_marketplace_orders()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  pending_order record;
  expired_count integer := 0;
begin
  for pending_order in
    select orders.id
    from public.marketplace_orders orders
    where orders.status = 'pending'
      and orders.expires_at <= now()
    order by orders.expires_at, orders.id
    for update skip locked
  loop
    update public.collection_items listing
    set quantity = listing.quantity + items.quantity
    from public.marketplace_order_items items
    where items.order_id = pending_order.id
      and listing.id = items.listing_id;

    update public.marketplace_orders
    set status = 'expired', resolved_at = now()
    where id = pending_order.id
      and status = 'pending';

    expired_count := expired_count + 1;
  end loop;

  return expired_count;
end;
$$;

create or replace function public.reserve_marketplace_items(p_items jsonb)
returns table (order_id uuid, reservation_expires_at timestamptz)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  buyer_user_id uuid := (select auth.uid());
  seller_user_id uuid;
  new_order_id uuid;
  new_expiration timestamptz := now() + interval '24 hours';
  request_item jsonb;
  listing_id_value uuid;
  requested_quantity integer;
  listing_record public.collection_items%rowtype;
  buyer_display_name text := '';
  buyer_phone text := '';
  seller_display_name text := '';
  seller_phone text := '';
begin
  if buyer_user_id is null then
    raise exception 'Entre na sua conta para reservar cartas.';
  end if;

  if p_items is null
    or jsonb_typeof(p_items) <> 'array'
    or jsonb_array_length(p_items) = 0 then
    raise exception 'Selecione ao menos uma carta para reservar.';
  end if;

  if jsonb_array_length(p_items) > 50 then
    raise exception 'Cada reserva aceita no maximo 50 anuncios.';
  end if;

  if (
    select count(distinct value->>'listing_id')
    from jsonb_array_elements(p_items)
  ) <> jsonb_array_length(p_items) then
    raise exception 'A mesma carta foi enviada mais de uma vez.';
  end if;

  perform public.expire_marketplace_orders();

  if (
    select count(*)
    from public.marketplace_orders orders
    where orders.buyer_id = buyer_user_id
      and orders.status = 'pending'
      and orders.expires_at > now()
  ) >= 10 then
    raise exception 'Voce ja possui 10 reservas pendentes. Resolva ou cancele uma delas antes de continuar.';
  end if;

  for request_item in
    select value
    from jsonb_array_elements(p_items)
    order by value->>'listing_id'
  loop
    begin
      listing_id_value := (request_item->>'listing_id')::uuid;
      requested_quantity := (request_item->>'quantity')::integer;
    exception when others then
      raise exception 'Item ou quantidade invalida na reserva.';
    end;

    if requested_quantity is null or requested_quantity <= 0 then
      raise exception 'A quantidade reservada deve ser maior que zero.';
    end if;

    select listing.*
    into listing_record
    from public.collection_items listing
    where listing.id = listing_id_value
    for update;

    if not found then
      raise exception 'Um dos anuncios nao esta mais disponivel.';
    end if;

    if listing_record.collection_type <> 'forSale'
      or not coalesce(listing_record.is_public, false)
      or listing_record.sale_status <> 'active'
      or listing_record.sale_expires_at is null
      or listing_record.sale_expires_at <= now() then
      raise exception 'Um dos anuncios nao esta mais ativo no marketplace.';
    end if;

    if listing_record.user_id = buyer_user_id then
      raise exception 'Voce nao pode reservar o seu proprio anuncio.';
    end if;

    if seller_user_id is null then
      seller_user_id := listing_record.user_id;
    elsif seller_user_id <> listing_record.user_id then
      raise exception 'Crie uma reserva separada para cada vendedor.';
    end if;

    if listing_record.quantity < requested_quantity then
      raise exception 'Estoque insuficiente para uma das cartas selecionadas.';
    end if;
  end loop;

  select coalesce(profile.name, ''), coalesce(profile.whatsapp_phone, '')
  into buyer_display_name, buyer_phone
  from public.profiles profile
  where profile.id = buyer_user_id;

  if btrim(coalesce(buyer_phone, '')) = '' then
    raise exception 'Cadastre seu WhatsApp no perfil antes de reservar cartas.';
  end if;

  select coalesce(profile.name, ''), coalesce(profile.whatsapp_phone, '')
  into seller_display_name, seller_phone
  from public.profiles profile
  where profile.id = seller_user_id;

  insert into public.marketplace_orders (
    seller_id,
    buyer_id,
    status,
    buyer_name,
    buyer_contact,
    seller_name,
    seller_contact,
    expires_at
  ) values (
    seller_user_id,
    buyer_user_id,
    'pending',
    coalesce(buyer_display_name, ''),
    coalesce(buyer_phone, ''),
    coalesce(seller_display_name, ''),
    coalesce(seller_phone, ''),
    new_expiration
  )
  returning id into new_order_id;

  for request_item in
    select value
    from jsonb_array_elements(p_items)
    order by value->>'listing_id'
  loop
    listing_id_value := (request_item->>'listing_id')::uuid;
    requested_quantity := (request_item->>'quantity')::integer;

    select listing.*
    into listing_record
    from public.collection_items listing
    where listing.id = listing_id_value
    for update;

    update public.collection_items
    set quantity = quantity - requested_quantity
    where id = listing_id_value;

    insert into public.marketplace_order_items (
      order_id,
      listing_id,
      quantity,
      unit_price_cents,
      game_slug,
      card_code,
      card_name,
      image_url,
      card_condition
    ) values (
      new_order_id,
      listing_id_value,
      requested_quantity,
      listing_record.sale_price_cents,
      coalesce(listing_record.game_slug, 'one-piece'),
      coalesce(listing_record.card_code, ''),
      coalesce(listing_record.name, listing_record.card_code, ''),
      coalesce(listing_record.image_url, ''),
      coalesce(listing_record.card_condition, 'mint')
    );
  end loop;

  return query select new_order_id, new_expiration;
end;
$$;

create or replace function public.resolve_marketplace_order(
  p_order_id uuid,
  p_action text
)
returns table (order_status text, resolved_at timestamptz)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_user_id uuid := (select auth.uid());
  order_record public.marketplace_orders%rowtype;
  normalized_action text := lower(btrim(coalesce(p_action, '')));
  next_status text;
  resolution_time timestamptz := now();
begin
  if current_user_id is null then
    raise exception 'Entre na sua conta para resolver a reserva.';
  end if;

  perform public.expire_marketplace_orders();

  select orders.*
  into order_record
  from public.marketplace_orders orders
  where orders.id = p_order_id
  for update;

  if not found then
    raise exception 'Reserva nao encontrada.';
  end if;

  if order_record.status <> 'pending' then
    raise exception 'Esta reserva ja foi resolvida.';
  end if;

  if normalized_action = 'confirm' then
    if order_record.seller_id <> current_user_id then
      raise exception 'Somente o vendedor pode confirmar a venda.';
    end if;
    next_status := 'confirmed';
  elsif normalized_action = 'reject' then
    if order_record.seller_id <> current_user_id then
      raise exception 'Somente o vendedor pode recusar a venda.';
    end if;
    next_status := 'cancelled';
  elsif normalized_action = 'cancel' then
    if order_record.buyer_id <> current_user_id then
      raise exception 'Somente o comprador pode cancelar a reserva.';
    end if;
    next_status := 'cancelled';
  else
    raise exception 'Acao invalida para a reserva.';
  end if;

  if next_status = 'cancelled' then
    update public.collection_items listing
    set quantity = listing.quantity + items.quantity
    from public.marketplace_order_items items
    where items.order_id = order_record.id
      and listing.id = items.listing_id;
  end if;

  update public.marketplace_orders
  set status = next_status,
      confirmed_at = case
        when next_status = 'confirmed' then resolution_time
        else confirmed_at
      end,
      resolved_at = resolution_time
  where id = order_record.id;

  return query select next_status, resolution_time;
end;
$$;

revoke all on function public.expire_marketplace_orders() from public;
revoke all on function public.reserve_marketplace_items(jsonb) from public;
revoke all on function public.resolve_marketplace_order(uuid, text) from public;
grant execute on function public.expire_marketplace_orders() to authenticated;
grant execute on function public.reserve_marketplace_items(jsonb) to authenticated;
grant execute on function public.resolve_marketplace_order(uuid, text)
to authenticated;

drop policy if exists "Public can read public marketplace listings"
on public.collection_items;
create policy "Public can read public marketplace listings"
on public.collection_items for select to anon, authenticated
using (
  collection_type = 'forSale'
  and is_public = true
  and sale_status = 'active'
  and quantity > 0
  and sale_expires_at is not null
  and sale_expires_at > now()
);

create or replace function public.get_public_marketplace_listing_contact(
  listing_id uuid
)
returns text
language sql
security definer
set search_path = public, pg_temp
as $$
  select coalesce(listing.sale_contact_info, '')
  from public.collection_items listing
  where (select auth.uid()) is not null
    and listing.id = listing_id
    and listing.collection_type = 'forSale'
    and listing.is_public = true
    and listing.sale_status = 'active'
    and listing.quantity > 0
    and listing.sale_expires_at is not null
    and listing.sale_expires_at > now()
  limit 1;
$$;

revoke all on function public.get_public_marketplace_listing_contact(uuid)
from public;
grant execute on function public.get_public_marketplace_listing_contact(uuid)
to authenticated;

do $$
declare
  existing_job_id bigint;
begin
  select jobid into existing_job_id
  from cron.job
  where jobname = 'expire-marketplace-orders'
  limit 1;

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'expire-marketplace-orders',
    '*/5 * * * *',
    'select public.expire_marketplace_orders();'
  );
end;
$$;
