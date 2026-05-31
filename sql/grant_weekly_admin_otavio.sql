-- Run once in the Supabase SQL Editor. The user must sign out and sign in
-- again after this change so the refreshed JWT includes app_metadata.
update auth.users
set raw_app_meta_data =
  coalesce(raw_app_meta_data, '{}'::jsonb) ||
  '{"is_weekly_admin": true}'::jsonb
where lower(email) = lower('otavio_cabalyes008@hotmail.com');

select
  email,
  raw_app_meta_data ->> 'is_weekly_admin' as is_weekly_admin
from auth.users
where lower(email) = lower('otavio_cabalyes008@hotmail.com');
