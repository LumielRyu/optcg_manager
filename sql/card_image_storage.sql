-- Public CDN bucket used by scripts/sync_supabase_card_images.py.
-- Uploads are performed only by the maintenance script with service_role.
-- The application reads public URLs and never exposes privileged credentials.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'card-images',
  'card-images',
  true,
  6291456,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
