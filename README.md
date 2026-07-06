# optcg_manager

Flutter app for managing OPTCG collection, sales, wanted cards, and weekly events.

## Build Web

The web build must receive only public browser configuration through
`--dart-define`. Do not bundle `.env` as a Flutter asset because it can contain
server-only secrets such as Supabase service role keys and R2 credentials.

On Windows, from the project root:

```powershell
python scripts/build_web_public_env.py
```

The script reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from the shell
environment or local `.env`, and passes only those public values to Flutter.

## External Asset Storage

The first step to reduce Supabase Storage usage is moving card image assets to an S3-compatible server while keeping Supabase Auth/Postgres for user data.

See [infra/storage/minio/README.md](infra/storage/minio/README.md) for the dual Xeon storage-server setup and migration flow.
