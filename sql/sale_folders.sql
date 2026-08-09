-- Pastas independentes para organizar cartas a venda em todos os TCGs.

create table if not exists public.sale_folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  game_slug text not null,
  name text not null,
  created_at timestamptz not null default now(),
  constraint sale_folders_name_check
    check (char_length(btrim(name)) between 1 and 60),
  constraint sale_folders_game_slug_check
    check (game_slug in (
      'one-piece', 'pokemon', 'digimon', 'magic', 'riftbound', 'yugioh'
    ))
);

create unique index if not exists idx_sale_folders_unique_name
  on public.sale_folders (user_id, game_slug, lower(btrim(name)));
create index if not exists idx_sale_folders_user_game_name
  on public.sale_folders (user_id, game_slug, name);

alter table public.collection_items
  add column if not exists sale_folder_id uuid
  references public.sale_folders(id) on delete set null;

create index if not exists idx_collection_items_sale_folder
  on public.collection_items (user_id, game_slug, sale_folder_id, created_at desc)
  where collection_type = 'forSale';

create or replace function public.validate_sale_item_folder()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.sale_folder_id is null then
    return new;
  end if;

  if new.collection_type <> 'forSale' then
    raise exception 'Somente cartas a venda podem usar pastas de venda.';
  end if;

  if not exists (
    select 1
    from public.sale_folders folder
    where folder.id = new.sale_folder_id
      and folder.user_id = new.user_id
      and folder.game_slug = coalesce(new.game_slug, 'one-piece')
  ) then
    raise exception 'A pasta precisa pertencer ao mesmo usuario e TCG da carta.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_sale_item_folder
  on public.collection_items;
create trigger trg_validate_sale_item_folder
before insert or update of sale_folder_id, user_id, game_slug, collection_type
on public.collection_items
for each row execute function public.validate_sale_item_folder();

alter table public.sale_folders enable row level security;
grant select, insert, update, delete on public.sale_folders to authenticated;

drop policy if exists "Users can read own sale folders" on public.sale_folders;
create policy "Users can read own sale folders"
  on public.sale_folders for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can insert own sale folders" on public.sale_folders;
create policy "Users can insert own sale folders"
  on public.sale_folders for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update own sale folders" on public.sale_folders;
create policy "Users can update own sale folders"
  on public.sale_folders for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete own sale folders" on public.sale_folders;
create policy "Users can delete own sale folders"
  on public.sale_folders for delete to authenticated
  using (auth.uid() = user_id);
