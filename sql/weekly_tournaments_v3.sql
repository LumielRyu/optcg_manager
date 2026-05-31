-- Weekly tournaments v3: trustworthy registered names in the ranking.
-- Run after weekly_tournaments_v2.sql.

alter table public.weekly_participants
add column if not exists player_display_name text;

update public.weekly_participants participant
set player_display_name = coalesce(nullif(profile.name, ''), participant.player_name)
from public.profiles profile
where profile.id = participant.user_id
  and (
    participant.player_display_name is null
    or participant.player_display_name = ''
  );

update public.weekly_participants
set player_display_name = player_name
where player_display_name is null
  or player_display_name = '';

alter table public.weekly_participants
alter column player_display_name set not null;

create or replace function private.fill_weekly_participant_display_name()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  select coalesce(nullif(profile.name, ''), new.player_name)
  into new.player_display_name
  from public.profiles profile
  where profile.id = new.user_id;

  new.player_display_name := coalesce(
    nullif(new.player_display_name, ''),
    new.player_name
  );
  return new;
end;
$$;

drop trigger if exists trg_fill_weekly_participant_display_name
on public.weekly_participants;

create trigger trg_fill_weekly_participant_display_name
before insert or update of user_id, player_name, player_display_name
on public.weekly_participants
for each row execute function private.fill_weekly_participant_display_name();
