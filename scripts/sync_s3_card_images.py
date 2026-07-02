import argparse
import mimetypes
import os
import pathlib


DEFAULT_IMAGE_DIR = pathlib.Path(".cache/card_images")
DEFAULT_BUCKET = "card-images"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Upload cached visual card catalog images to an S3-compatible bucket."
    )
    parser.add_argument("--image-dir", type=pathlib.Path, default=DEFAULT_IMAGE_DIR)
    parser.add_argument("--bucket", default=DEFAULT_BUCKET)
    parser.add_argument(
        "--endpoint-url",
        default=os.environ.get("S3_ENDPOINT_URL", ""),
        help="S3-compatible endpoint, e.g. https://assets.optcgmanager.com.",
    )
    parser.add_argument(
        "--public-base-url",
        default=os.environ.get("CARD_IMAGE_PUBLIC_BASE_URL", ""),
        help="Public URL prefix for generated catalog image URLs.",
    )
    parser.add_argument(
        "--access-key-id",
        default=os.environ.get("S3_ACCESS_KEY_ID", ""),
        help="S3 access key id. Defaults to S3_ACCESS_KEY_ID.",
    )
    parser.add_argument(
        "--secret-access-key",
        default=os.environ.get("S3_SECRET_ACCESS_KEY", ""),
        help="S3 secret access key. Defaults to S3_SECRET_ACCESS_KEY.",
    )
    parser.add_argument("--region", default=os.environ.get("S3_REGION", "us-east-1"))
    parser.add_argument("--force", action="store_true")
    parser.add_argument(
        "--limit",
        type=int,
        help="Upload only the first N images. Useful for validating credentials.",
    )
    return parser.parse_args()


def load_boto3():
    try:
        import boto3
        from botocore.exceptions import ClientError
    except ImportError as error:
        raise SystemExit(
            "Install boto3 first: python -m pip install boto3"
        ) from error

    return boto3, ClientError


def object_exists(client, bucket: str, key: str, client_error_type) -> bool:
    try:
        client.head_object(Bucket=bucket, Key=key)
        return True
    except client_error_type as error:
        code = str(error.response.get("Error", {}).get("Code", ""))
        if code in {"404", "NoSuchKey", "NotFound"}:
            return False
        raise


def main():
    args = parse_args()
    if not args.image_dir.exists():
        raise SystemExit(
            f"{args.image_dir} does not exist. Run generate_visual_fingerprints.py first."
        )
    if not args.endpoint_url:
        raise SystemExit("Set --endpoint-url or S3_ENDPOINT_URL.")
    if not args.access_key_id or not args.secret_access_key:
        raise SystemExit("Set S3_ACCESS_KEY_ID and S3_SECRET_ACCESS_KEY.")

    boto3, client_error_type = load_boto3()
    client = boto3.client(
        "s3",
        endpoint_url=args.endpoint_url.rstrip("/"),
        aws_access_key_id=args.access_key_id,
        aws_secret_access_key=args.secret_access_key,
        region_name=args.region,
    )

    files = [path for path in args.image_dir.rglob("*") if path.is_file()]
    if args.limit is not None:
        files = files[: max(0, args.limit)]

    uploaded = 0
    skipped = 0

    for index, path in enumerate(files, start=1):
        key = path.relative_to(args.image_dir).as_posix()

        if not args.force and object_exists(
            client,
            args.bucket,
            key,
            client_error_type,
        ):
            skipped += 1
            continue

        content_type = mimetypes.guess_type(path.name)[0] or "image/jpeg"
        client.upload_file(
            str(path),
            args.bucket,
            key,
            ExtraArgs={
                "ContentType": content_type,
                "CacheControl": "public, max-age=31536000, immutable",
            },
        )
        uploaded += 1

        if index % 100 == 0 or index == len(files):
            print(f"[{index}/{len(files)}] uploaded={uploaded} skipped={skipped}")

    public_base_url = args.public_base_url.rstrip("/")
    print(f"sync complete: uploaded={uploaded} skipped={skipped}")
    if public_base_url:
        print("regenerate the app catalog with:")
        print(
            "python scripts/generate_visual_fingerprints.py "
            f"--public-base-url {public_base_url}"
        )


if __name__ == "__main__":
    main()

