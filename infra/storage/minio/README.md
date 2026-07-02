# OPTCG Manager Storage Server

This folder contains the first storage-only server setup for moving card image assets out of Supabase Storage while keeping Supabase Auth/Postgres as the system of record.

## Target Architecture

- Vercel keeps hosting the Flutter web app.
- Supabase keeps Auth, Postgres, RLS, and user data.
- The dual Xeon server runs MinIO as an S3-compatible object store.
- A public domain such as `assets.optcgmanager.com` serves read-only card images.
- Admin access to MinIO stays private through SSH/VPN/Cloudflare Access.

## Server Prep

Recommended baseline:

- Ubuntu Server 24.04 LTS or Debian 12.
- Static LAN IP.
- Wired connection.
- SSD/NVMe for OS and MinIO metadata, larger disks for object data.
- UPS if possible.
- Nightly off-server backups.

Run the bootstrap script on the server:

```bash
sudo bash bootstrap.sh
```

Prepare the environment file:

```bash
cp .env.example .env
nano .env
```

Then copy the runtime files into the server app directory:

```bash
sudo cp docker-compose.yml .env /srv/optcg/minio/
sudo cp backup_minio.sh /srv/optcg/minio/
sudo cp minio-backup.service minio-backup.timer /srv/optcg/minio/
sudo chmod +x /srv/optcg/minio/backup_minio.sh
```

Start MinIO:

```bash
cd /srv/optcg/minio
docker compose up -d
```

After the first successful pull on the server, pin `quay.io/minio/minio:latest` in `docker-compose.yml` to the exact release digest/tag you validated.

The compose file binds MinIO to `127.0.0.1` only. Expose it through a reverse proxy or Cloudflare Tunnel rather than opening the admin/API ports directly to the internet.

## Cloudflare Tunnel

Cloudflare Tunnel is the recommended first option because it avoids opening inbound ports on your home network.

1. Install `cloudflared` on the server.
2. Create a tunnel in Cloudflare Zero Trust.
3. Copy `cloudflared.example.yml` to `/etc/cloudflared/config.yml`.
4. Replace:
   - `assets.example.com` with your public image domain.
   - `minio-admin.example.com` with an admin-only hostname protected by Cloudflare Access.
   - `credentials-file` with the path Cloudflare generated.

Run:

```bash
sudo cloudflared service install
sudo systemctl enable --now cloudflared
```

Protect `minio-admin.example.com` with Cloudflare Access. Do not leave the MinIO console open to the public internet.

## Bucket Setup

Create a bucket named `card-images` and make only that bucket publicly readable:

```bash
set -a
. ./.env
set +a
docker run --rm --network host quay.io/minio/mc alias set local http://127.0.0.1:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
docker run --rm --network host quay.io/minio/mc mb --ignore-existing local/card-images
docker run --rm --network host quay.io/minio/mc anonymous set download local/card-images
```

Keep the root credentials private. For regular syncs, create a restricted access key that can write only to `card-images`.

## Backups

Install backup dependencies:

```bash
sudo apt-get install -y zstd
```

Run a manual backup:

```bash
sudo /srv/optcg/minio/backup_minio.sh
```

Enable the daily systemd timer:

```bash
sudo cp minio-backup.service minio-backup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now minio-backup.timer
```

The local backup is not enough. Mirror `/srv/optcg/minio/backups` to another disk or cloud location. A storage server without off-server backup is still a single point of failure.

## Sync Images

From the project root on your development machine:

```bash
python scripts/sync_s3_card_images.py \
  --endpoint-url https://assets.optcgmanager.com \
  --bucket card-images \
  --public-base-url https://assets.optcgmanager.com/card-images
```

Then regenerate the visual catalog:

```bash
python scripts/generate_visual_fingerprints.py \
  --public-base-url https://assets.optcgmanager.com/card-images
```

Commit the updated `assets/visual_card_fingerprints.json` only after validating that images load from the new domain.

## Migration Order

1. Bring up MinIO on the server.
2. Put it behind HTTPS.
3. Create the `card-images` bucket.
4. Sync existing `.cache/card_images`.
5. Regenerate `assets/visual_card_fingerprints.json` using the new public URL.
6. Deploy the app.
7. After verification, remove old objects from Supabase Storage.

## Useful Checks

```bash
docker compose ps
docker compose logs --tail=100 minio
curl -I https://assets.optcgmanager.com/card-images/one-piece/
systemctl list-timers | grep minio-backup
```

Do not move Supabase Postgres/Auth to the home server until backups, monitoring, dynamic DNS/static IP, restore drills, and uptime expectations are settled.
