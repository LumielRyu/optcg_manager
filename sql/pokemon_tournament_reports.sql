-- Pokemon TCG reports imported from the official tournament .tdf file.
-- Run after weekly_tournaments.sql so public.is_weekly_admin() exists.

create extension if not exists pgcrypto;

create table if not exists public.pokemon_tournament_reports (
  id uuid primary key default gen_random_uuid(),
  source_key text not null unique,
  source_file_name text not null,
  event_name text not null,
  event_date date not null,
  participant_count integer not null check (participant_count >= 0),
  round_count integer not null check (round_count >= 0),
  match_count integer not null check (match_count >= 0),
  report_data jsonb not null check (jsonb_typeof(report_data) = 'object'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_pokemon_tournament_reports_event_date
on public.pokemon_tournament_reports (event_date desc);

create index if not exists idx_pokemon_tournament_reports_created_by
on public.pokemon_tournament_reports (created_by);

alter table public.pokemon_tournament_reports enable row level security;

grant select on public.pokemon_tournament_reports to anon, authenticated;
grant insert, update, delete on public.pokemon_tournament_reports to authenticated;

drop policy if exists "Pokemon reports are publicly readable"
on public.pokemon_tournament_reports;
create policy "Pokemon reports are publicly readable"
on public.pokemon_tournament_reports
for select
to anon, authenticated
using (true);

drop policy if exists "Weekly admins insert Pokemon reports"
on public.pokemon_tournament_reports;
create policy "Weekly admins insert Pokemon reports"
on public.pokemon_tournament_reports
for insert
to authenticated
with check (
  (select public.is_weekly_admin())
  and created_by = (select auth.uid())
);

drop policy if exists "Weekly admins update Pokemon reports"
on public.pokemon_tournament_reports;
create policy "Weekly admins update Pokemon reports"
on public.pokemon_tournament_reports
for update
to authenticated
using ((select public.is_weekly_admin()))
with check (
  (select public.is_weekly_admin())
  and created_by = (select auth.uid())
);

drop policy if exists "Weekly admins delete Pokemon reports"
on public.pokemon_tournament_reports;
create policy "Weekly admins delete Pokemon reports"
on public.pokemon_tournament_reports
for delete
to authenticated
using ((select public.is_weekly_admin()));
