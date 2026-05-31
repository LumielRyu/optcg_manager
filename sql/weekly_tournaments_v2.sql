-- Weekly tournaments v2: player enrollment, per-game profiles, byes and
-- opponent confirmation. Run after weekly_tournaments.sql.

create table if not exists public.weekly_game_profiles (
  user_id uuid not null references auth.users(id) on delete cascade,
  game_slug text not null check (game_slug in (
    'one-piece', 'pokemon', 'yugioh', 'digimon', 'magic', 'riftbound'
  )),
  nickname text not null,
  bandai_code text,
  updated_at timestamptz not null default now(),
  primary key (user_id, game_slug)
);

alter table public.weekly_participants
add column if not exists leader_code text;

alter table public.weekly_participants
add column if not exists leader_name text;

alter table public.weekly_matches
alter column player_two_id drop not null;

alter table public.weekly_matches
add column if not exists match_type text not null default 'regular'
check (match_type in ('regular', 'bye'));

alter table public.weekly_matches
add column if not exists result_status text not null default 'confirmed'
check (result_status in ('scheduled', 'pending_confirmation', 'confirmed', 'disputed'));

alter table public.weekly_matches
add column if not exists reported_by uuid references auth.users(id);

alter table public.weekly_matches
add column if not exists confirmed_by uuid references auth.users(id);

alter table public.weekly_matches
add column if not exists disputed_by uuid references auth.users(id);

alter table public.weekly_matches
drop constraint if exists weekly_matches_check;

alter table public.weekly_matches
add constraint weekly_matches_players_check check (
  (match_type = 'bye' and player_two_id is null and result = 'bye')
  or
  (match_type = 'regular' and player_two_id is not null and player_one_id <> player_two_id)
);

alter table public.weekly_matches
drop constraint if exists weekly_matches_result_check;

alter table public.weekly_matches
add constraint weekly_matches_result_check check (
  result in ('scheduled', 'player_one', 'draw', 'player_two', 'bye')
);

update public.weekly_matches
set result_status = case
  when result = 'scheduled' then 'scheduled'
  else 'confirmed'
end;

create index if not exists idx_weekly_game_profiles_game
on public.weekly_game_profiles (game_slug, nickname);

create index if not exists idx_weekly_matches_player_one
on public.weekly_matches (player_one_id);

create index if not exists idx_weekly_matches_player_two
on public.weekly_matches (player_two_id)
where player_two_id is not null;

create unique index if not exists idx_weekly_matches_unique_bye
on public.weekly_matches (weekly_event_id, round_number, player_one_id)
where match_type = 'bye';

alter table public.weekly_game_profiles enable row level security;

grant select, insert, update on public.weekly_game_profiles to authenticated;
grant insert, update on public.weekly_participants to authenticated;
grant update (
  result,
  result_status,
  reported_by,
  confirmed_by,
  disputed_by,
  updated_at
) on public.weekly_matches to authenticated;

drop policy if exists "Users manage own weekly game profile" on public.weekly_game_profiles;
create policy "Users manage own weekly game profile"
on public.weekly_game_profiles for all to authenticated
using ((select auth.uid()) = user_id or (select public.is_weekly_admin()))
with check ((select auth.uid()) = user_id or (select public.is_weekly_admin()));

drop policy if exists "Users can join open weekly events" on public.weekly_participants;
create policy "Users can join open weekly events"
on public.weekly_participants for insert to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.weekly_events event
    where event.id = weekly_event_id
      and event.status = 'open'
  )
);

drop policy if exists "Users can update own open weekly enrollment" on public.weekly_participants;
create policy "Users can update own open weekly enrollment"
on public.weekly_participants for update to authenticated
using (
  user_id = (select auth.uid())
  and exists (
    select 1
    from public.weekly_events event
    where event.id = weekly_event_id
      and event.status = 'open'
  )
)
with check (user_id = (select auth.uid()));

drop policy if exists "Players can update their match result" on public.weekly_matches;
create policy "Players can update their match result"
on public.weekly_matches for update to authenticated
using (
  match_type = 'regular'
  and exists (
    select 1
    from public.weekly_participants participant
    where participant.id in (player_one_id, player_two_id)
      and participant.user_id = (select auth.uid())
  )
)
with check (
  match_type = 'regular'
  and exists (
    select 1
    from public.weekly_participants participant
    where participant.id in (player_one_id, player_two_id)
      and participant.user_id = (select auth.uid())
  )
);

create schema if not exists private;

create or replace function private.validate_weekly_match_result_update()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
declare
  current_user_id uuid := auth.uid();
  is_admin boolean := public.is_weekly_admin();
  is_player boolean;
begin
  if is_admin then
    if new.result = 'scheduled' then
      new.result_status := 'scheduled';
      new.confirmed_by := null;
    else
      new.result_status := 'confirmed';
      new.confirmed_by := current_user_id;
    end if;
    new.updated_at := now();
    return new;
  end if;

  select exists (
    select 1
    from public.weekly_participants participant
    where participant.id in (old.player_one_id, old.player_two_id)
      and participant.user_id = current_user_id
  ) into is_player;

  if not is_player or old.match_type <> 'regular' then
    raise exception 'Only players in a regular match can report its result.';
  end if;

  if old.result_status in ('scheduled', 'disputed') then
    if new.result not in ('player_one', 'draw', 'player_two') then
      raise exception 'Choose a valid match result.';
    end if;
    new.result_status := 'pending_confirmation';
    new.reported_by := current_user_id;
    new.confirmed_by := null;
    new.disputed_by := null;
  elsif old.result_status = 'pending_confirmation'
    and old.reported_by <> current_user_id then
    if new.result <> old.result then
      raise exception 'The opponent can only confirm or dispute the reported result.';
    end if;
    if new.result_status = 'confirmed' then
      new.confirmed_by := current_user_id;
      new.disputed_by := null;
    elsif new.result_status = 'disputed' then
      new.disputed_by := current_user_id;
      new.confirmed_by := null;
    else
      raise exception 'Confirm or dispute the reported result.';
    end if;
  else
    raise exception 'This result cannot be changed by the current player.';
  end if;

  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_validate_weekly_match_result_update
on public.weekly_matches;

create trigger trg_validate_weekly_match_result_update
before update of result, result_status
on public.weekly_matches
for each row execute function private.validate_weekly_match_result_update();
