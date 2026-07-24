-- Administrative audit trail and restore support for Pokemon TDF reports.
-- Run after pokemon_tournament_reports.sql.

create table if not exists public.pokemon_tournament_report_audit (
  id bigint generated always as identity primary key,
  report_id uuid not null,
  action text not null check (action in ('insert', 'update', 'delete')),
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now(),
  source_key text not null,
  previous_data jsonb check (
    previous_data is null or jsonb_typeof(previous_data) = 'object'
  ),
  new_data jsonb check (
    new_data is null or jsonb_typeof(new_data) = 'object'
  )
);

create index if not exists idx_pokemon_report_audit_report_changed
on public.pokemon_tournament_report_audit (report_id, changed_at desc);

create index if not exists idx_pokemon_report_audit_changed_at
on public.pokemon_tournament_report_audit (changed_at desc);

alter table public.pokemon_tournament_report_audit enable row level security;

revoke all on public.pokemon_tournament_report_audit from anon;
revoke all on public.pokemon_tournament_report_audit from authenticated;
grant select on public.pokemon_tournament_report_audit to authenticated;

drop policy if exists "Weekly admins read Pokemon report audit"
on public.pokemon_tournament_report_audit;
create policy "Weekly admins read Pokemon report audit"
on public.pokemon_tournament_report_audit
for select
to authenticated
using ((select public.is_weekly_admin()));

create or replace function public.audit_pokemon_tournament_report_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  old_data jsonb;
  new_data jsonb;
  current_report_id uuid;
  current_source_key text;
begin
  if tg_op = 'INSERT' then
    old_data := null;
    new_data := to_jsonb(new);
    current_report_id := new.id;
    current_source_key := new.source_key;
  elsif tg_op = 'DELETE' then
    old_data := to_jsonb(old);
    new_data := null;
    current_report_id := old.id;
    current_source_key := old.source_key;
  else
    old_data := to_jsonb(old);
    new_data := to_jsonb(new);
    current_report_id := new.id;
    current_source_key := new.source_key;
  end if;

  insert into public.pokemon_tournament_report_audit (
    report_id,
    action,
    changed_by,
    source_key,
    previous_data,
    new_data
  ) values (
    current_report_id,
    lower(tg_op),
    (select auth.uid()),
    current_source_key,
    old_data,
    new_data
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function public.audit_pokemon_tournament_report_change()
from public;

drop trigger if exists trg_audit_pokemon_tournament_reports
on public.pokemon_tournament_reports;
create trigger trg_audit_pokemon_tournament_reports
after insert or update or delete
on public.pokemon_tournament_reports
for each row execute function public.audit_pokemon_tournament_report_change();

create or replace function public.restore_pokemon_tournament_report_audit(
  audit_id bigint
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  snapshot jsonb;
  restored public.pokemon_tournament_reports%rowtype;
begin
  if not (select public.is_weekly_admin()) then
    raise exception 'Weekly administrator permission required';
  end if;

  select previous_data
  into snapshot
  from public.pokemon_tournament_report_audit
  where id = audit_id;

  if snapshot is null then
    raise exception 'This audit entry does not have a previous version';
  end if;

  restored := jsonb_populate_record(
    null::public.pokemon_tournament_reports,
    snapshot
  );

  insert into public.pokemon_tournament_reports (
    id,
    source_key,
    source_file_name,
    event_name,
    event_date,
    participant_count,
    round_count,
    match_count,
    report_data,
    created_by,
    created_at,
    updated_at
  ) values (
    restored.id,
    restored.source_key,
    restored.source_file_name,
    restored.event_name,
    restored.event_date,
    restored.participant_count,
    restored.round_count,
    restored.match_count,
    restored.report_data,
    restored.created_by,
    restored.created_at,
    now()
  )
  on conflict (id) do update set
    source_key = excluded.source_key,
    source_file_name = excluded.source_file_name,
    event_name = excluded.event_name,
    event_date = excluded.event_date,
    participant_count = excluded.participant_count,
    round_count = excluded.round_count,
    match_count = excluded.match_count,
    report_data = excluded.report_data,
    updated_at = now();

  return restored.id;
end;
$$;

revoke all on function public.restore_pokemon_tournament_report_audit(bigint)
from public;
grant execute on function public.restore_pokemon_tournament_report_audit(bigint)
to authenticated;
