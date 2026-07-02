# optcg_manager

Flutter app for managing OPTCG collection, sales, wanted cards, and weekly events.

## External Asset Storage

The first step to reduce Supabase Storage usage is moving card image assets to an S3-compatible server while keeping Supabase Auth/Postgres for user data.

See [infra/storage/minio/README.md](infra/storage/minio/README.md) for the dual Xeon storage-server setup and migration flow.
