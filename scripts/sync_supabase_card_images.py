import argparse
import mimetypes
import os
import pathlib
import urllib.error
import urllib.parse
import urllib.request


DEFAULT_IMAGE_DIR = pathlib.Path(".cache/card_images")
DEFAULT_BUCKET = "card-images"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Upload the cached visual card catalog images to Supabase Storage."
    )
    parser.add_argument("--image-dir", type=pathlib.Path, default=DEFAULT_IMAGE_DIR)
    parser.add_argument("--bucket", default=DEFAULT_BUCKET)
    parser.add_argument("--force", action="store_true")
    parser.add_argument(
        "--limit",
        type=int,
        help="Upload only the first N images. Useful for validating credentials.",
    )
    return parser.parse_args()


def request(url: str, *, method: str, headers: dict[str, str], data: bytes | None = None):
    return urllib.request.urlopen(
        urllib.request.Request(url, method=method, headers=headers, data=data),
        timeout=60,
    )


def format_http_error(error: urllib.error.HTTPError, *, action: str) -> str:
    body = error.read().decode("utf-8", errors="replace").strip()
    details = f": {body}" if body else ""
    return f"Supabase Storage rejected {action} (HTTP {error.code}){details}"


def main():
    args = parse_args()
    supabase_url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not supabase_url or not service_key:
        raise SystemExit(
            "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before syncing images."
        )
    if not service_key.startswith("eyJ"):
        raise SystemExit(
            "SUPABASE_SERVICE_ROLE_KEY must be the legacy service_role JWT starting "
            'with "eyJ". In Supabase, open Settings > API Keys > Legacy API keys.'
        )
    if not args.image_dir.exists():
        raise SystemExit(
            f"{args.image_dir} does not exist. Run generate_visual_fingerprints.py first."
        )

    headers = {"Authorization": f"Bearer {service_key}", "apikey": service_key}
    files = [path for path in args.image_dir.rglob("*") if path.is_file()]
    if args.limit is not None:
        files = files[: max(0, args.limit)]
    uploaded = 0
    skipped = 0

    for index, path in enumerate(files, start=1):
        relative_path = path.relative_to(args.image_dir).as_posix()
        encoded_path = urllib.parse.quote(relative_path, safe="/")
        public_url = (
            f"{supabase_url}/storage/v1/object/public/{args.bucket}/{encoded_path}"
        )
        upload_url = f"{supabase_url}/storage/v1/object/{args.bucket}/{encoded_path}"

        if not args.force:
            try:
                with request(public_url, method="HEAD", headers={}):
                    skipped += 1
                    continue
            except urllib.error.HTTPError as error:
                # The public Storage endpoint currently answers HEAD with HTTP 400
                # for missing objects. Upload remains the authoritative check.
                if error.code not in (400, 404):
                    raise SystemExit(
                        format_http_error(error, action=f"checking {relative_path}")
                    ) from error

        content_type = mimetypes.guess_type(path.name)[0] or "image/jpeg"
        upload_headers = {
            **headers,
            "Content-Type": content_type,
            "cache-control": "31536000",
            "x-upsert": "true" if args.force else "false",
        }
        try:
            with request(
                upload_url,
                method="POST",
                headers=upload_headers,
                data=path.read_bytes(),
            ):
                uploaded += 1
        except urllib.error.HTTPError as error:
            raise SystemExit(
                format_http_error(error, action=f"uploading {relative_path}")
            ) from error

        if index % 100 == 0 or index == len(files):
            print(f"[{index}/{len(files)}] uploaded={uploaded} skipped={skipped}")

    base_url = f"{supabase_url}/storage/v1/object/public/{args.bucket}"
    print(f"sync complete: uploaded={uploaded} skipped={skipped}")
    print("regenerate the app catalog with:")
    print(
        "python scripts/generate_visual_fingerprints.py "
        f"--public-base-url {base_url}"
    )


if __name__ == "__main__":
    main()
