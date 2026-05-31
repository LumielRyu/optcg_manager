-- Weekly tournament history shared by every supported card game.
-- Grant an admin role with:
-- update auth.users
-- set raw_app_meta_data =
--   coalesce(raw_app_meta_data, '{}'::jsonb) || '{"is_weekly_admin": true}'::jsonb
-- where id = '<user-id>';

create extension if not exists pgcrypto;

create or replace function public.is_weekly_admin()
returns boolean
language sql
stable
as $$
  select coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'is_weekly_admin')::boolean,
    false
  );
$$;

create table if not exists public.weekly_events (
  id uuid primary key default gen_random_uuid(),
  game_slug text not null check (game_slug in (
    'one-piece', 'pokemon', 'yugioh', 'digimon', 'magic', 'riftbound'
  )),
  title text not null,
  event_date date not null,
  status text not null default 'open' check (status in ('open', 'finished')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.weekly_participants (
  id uuid primary key default gen_random_uuid(),
  weekly_event_id uuid not null references public.weekly_events(id) on delete cascade,
  user_id uuid not null references auth.users(id),
  player_name text not null,
  deck_name text not null,
  created_at timestamptz not null default now(),
  unique (weekly_event_id, user_id)
);

create table if not exists public.weekly_matches (
  id uuid primary key default gen_random_uuid(),
  weekly_event_id uuid not null references public.weekly_events(id) on delete cascade,
  round_number integer not null check (round_number > 0),
  table_number integer check (table_number is null or table_number > 0),
  player_one_id uuid not null references public.weekly_participants(id) on delete cascade,
  player_two_id uuid not null references public.weekly_participants(id) on delete cascade,
  result text not null default 'scheduled'
    check (result in ('scheduled', 'player_one', 'draw', 'player_two')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (player_one_id <> player_two_id)
);

create index if not exists idx_weekly_events_game_date
on public.weekly_events (game_slug, event_date desc);

create index if not exists idx_weekly_participants_event
on public.weekly_participants (weekly_event_id);

create index if not exists idx_weekly_participants_user
on public.weekly_participants (user_id);

create index if not exists idx_weekly_matches_event_round
on public.weekly_matches (weekly_event_id, round_number, table_number);

alter table public.weekly_events enable row level security;
alter table public.weekly_participants enable row level security;
alter table public.weekly_matches enable row level security;

grant select on public.weekly_events, public.weekly_participants, public.weekly_matches
to authenticated;
grant insert, update, delete on public.weekly_events, public.weekly_participants, public.weekly_matches
to authenticated;
grant execute on function public.is_weekly_admin() to authenticated;

drop policy if exists "Authenticated users can read weekly events" on public.weekly_events;
create policy "Authenticated users can read weekly events"
on public.weekly_events for select to authenticated
using (true);

drop policy if exists "Weekly admins manage events" on public.weekly_events;
create policy "Weekly admins manage events"
on public.weekly_events for all to authenticated
using (public.is_weekly_admin())
with check (public.is_weekly_admin() and created_by = auth.uid());

drop policy if exists "Authenticated users can read weekly participants" on public.weekly_participants;
create policy "Authenticated users can read weekly participants"
on public.weekly_participants for select to authenticated
using (true);

drop policy if exists "Weekly admins manage participants" on public.weekly_participants;
create policy "Weekly admins manage participants"
on public.weekly_participants for all to authenticated
using (public.is_weekly_admin())
with check (public.is_weekly_admin());

drop policy if exists "Authenticated users can read weekly matches" on public.weekly_matches;
create policy "Authenticated users can read weekly matches"
on public.weekly_matches for select to authenticated
using (true);

drop policy if exists "Weekly admins manage matches" on public.weekly_matches;
create policy "Weekly admins manage matches"
on public.weekly_matches for all to authenticated
using (public.is_weekly_admin())
with check (public.is_weekly_admin() and created_by = auth.uid());

-- Admins need the profile list to enroll players. Regular users keep the
-- existing own-profile access policy from profiles_policies.sql.
drop policy if exists "Weekly admins can read player profiles" on public.profiles;
create policy "Weekly admins can read player profiles"
on public.profiles for select to authenticated
using (public.is_weekly_admin());
