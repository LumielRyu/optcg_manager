-- One Piece standings imported from the Bandai TCG+ *_standing.csv export.
-- Run after weekly_tournaments.sql so public.is_weekly_admin() exists.

create extension if not exists pgcrypto;

create table if not exists public.one_piece_tournament_reports (
  id uuid primary key default gen_random_uuid(),
  source_key text not null unique,
  source_file_name text not null,
  event_name text not null,
  event_date date not null,
  participant_count integer not null check (participant_count > 0),
  report_data jsonb not null check (jsonb_typeof(report_data) = 'object'),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_one_piece_tournament_reports_event_date
on public.one_piece_tournament_reports (event_date desc);

create index if not exists idx_one_piece_tournament_reports_created_by
on public.one_piece_tournament_reports (created_by);

alter table public.one_piece_tournament_reports enable row level security;

grant select on public.one_piece_tournament_reports to anon, authenticated;
grant insert, update, delete on public.one_piece_tournament_reports to authenticated;

drop policy if exists "One Piece reports are publicly readable" on public.one_piece_tournament_reports;
create policy "One Piece reports are publicly readable"
on public.one_piece_tournament_reports for select to anon, authenticated
using (true);

drop policy if exists "Weekly admins insert One Piece reports" on public.one_piece_tournament_reports;
create policy "Weekly admins insert One Piece reports"
on public.one_piece_tournament_reports for insert to authenticated
with check ((select public.is_weekly_admin()) and created_by = (select auth.uid()));

drop policy if exists "Weekly admins update One Piece reports" on public.one_piece_tournament_reports;
create policy "Weekly admins update One Piece reports"
on public.one_piece_tournament_reports for update to authenticated
using ((select public.is_weekly_admin()))
with check ((select public.is_weekly_admin()) and created_by = (select auth.uid()));

drop policy if exists "Weekly admins delete One Piece reports" on public.one_piece_tournament_reports;
create policy "Weekly admins delete One Piece reports"
on public.one_piece_tournament_reports for delete to authenticated
using ((select public.is_weekly_admin()));
