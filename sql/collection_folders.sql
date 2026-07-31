-- Pastas da colecao, compartilhadas pela fundacao multi-TCG.
-- Cartas existentes permanecem sem pasta.

create table if not exists public.collection_folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  game_slug text not null default 'one-piece',
  name text not null,
  created_at timestamptz not null default now(),
  constraint collection_folders_name_check
    check (char_length(btrim(name)) between 1 and 60),
  constraint collection_folders_game_slug_check
    check (
      game_slug in (
        'one-piece',
        'pokemon',
        'digimon',
        'magic',
        'riftbound',
        'yugioh'
      )
    )
);

create unique index if not exists idx_collection_folders_unique_name
on public.collection_folders (user_id, game_slug, lower(btrim(name)));

create index if not exists idx_collection_folders_user_game_created
on public.collection_folders (user_id, game_slug, created_at);

alter table public.collection_items
add column if not exists folder_id uuid
references public.collection_folders(id) on delete set null;

create index if not exists idx_collection_items_user_folder
on public.collection_items (user_id, folder_id, created_at desc);

create or replace function public.validate_collection_item_folder()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.folder_id is null then
    return new;
  end if;

  if not exists (
    select 1
    from public.collection_folders folder
    where folder.id = new.folder_id
      and folder.user_id = new.user_id
      and folder.game_slug = coalesce(new.game_slug, 'one-piece')
  ) then
    raise exception 'A pasta precisa pertencer ao mesmo usuario e TCG da carta.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validate_collection_item_folder
on public.collection_items;
create trigger trg_validate_collection_item_folder
before insert or update of folder_id, user_id, game_slug
on public.collection_items
for each row execute function public.validate_collection_item_folder();

alter table public.collection_folders enable row level security;

grant select, insert, update, delete
on public.collection_folders to authenticated;

drop policy if exists "Users can read own collection folders"
on public.collection_folders;
create policy "Users can read own collection folders"
on public.collection_folders for select to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can insert own collection folders"
on public.collection_folders;
create policy "Users can insert own collection folders"
on public.collection_folders for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can update own collection folders"
on public.collection_folders;
create policy "Users can update own collection folders"
on public.collection_folders for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can delete own collection folders"
on public.collection_folders;
create policy "Users can delete own collection folders"
on public.collection_folders for delete to authenticated
using (auth.uid() = user_id);
