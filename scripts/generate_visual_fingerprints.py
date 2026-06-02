import argparse
import concurrent.futures
import hashlib
import io
import json
import pathlib
import time
import urllib.request
from urllib.parse import urlparse

from PIL import Image, ImageOps


API_URLS = [
    "https://www.optcgapi.com/api/allSetCards/?format=json",
    "https://www.optcgapi.com/api/allSTCards/?format=json",
    "https://www.optcgapi.com/api/allPromos/?format=json",
]

OUTPUT_PATH = pathlib.Path("assets/visual_card_fingerprints.json")
DEFAULT_IMAGE_DIR = pathlib.Path(".cache/card_images")


def fetch_json(url: str):
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)


def image_path_for(card: dict, image_dir: pathlib.Path) -> pathlib.Path:
    code = str(card.get("card_set_id", "")).strip().upper()
    image_url = str(card.get("card_image", "")).strip()
    suffix = pathlib.Path(urlparse(image_url).path).suffix.lower() or ".jpg"
    digest = hashlib.sha1(image_url.encode("utf-8")).hexdigest()[:16]
    return image_dir / "one-piece" / code / f"{digest}{suffix}"


def load_image_bytes(url: str, path: pathlib.Path) -> bytes:
    if path.exists():
        return path.read_bytes()

    last_error = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=25) as response:
                content = response.read()
            break
        except Exception as error:
            last_error = error
            if attempt == 2:
                raise
            time.sleep(1.5 * (attempt + 1))
    else:
        raise last_error or RuntimeError(f"failed to download {url}")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)
    return content


def dhash(image: Image.Image, width: int = 9, height: int = 8) -> str:
    resized = image.resize((width, height), Image.Resampling.LANCZOS)
    grayscale = ImageOps.grayscale(resized)
    bits = []

    for y in range(height):
      for x in range(width - 1):
        left = grayscale.getpixel((x, y))
        right = grayscale.getpixel((x + 1, y))
        bits.append("1" if left > right else "0")

    return hex(int("".join(bits), 2))[2:].rjust(16, "0")


def crop_box(image: Image.Image, left: float, top: float, right: float, bottom: float) -> Image.Image:
    width, height = image.size
    box = (
        max(0, int(width * left)),
        max(0, int(height * top)),
        min(width, int(width * right)),
        min(height, int(height * bottom)),
    )
    return image.crop(box)


def average_rgb(image: Image.Image):
    resized = image.resize((32, 32), Image.Resampling.LANCZOS).convert("RGB")
    pixels = list(resized.get_flattened_data())
    total = len(pixels) or 1
    r = sum(pixel[0] for pixel in pixels) // total
    g = sum(pixel[1] for pixel in pixels) // total
    b = sum(pixel[2] for pixel in pixels) // total
    return [r, g, b]


def build_fingerprint(
    card: dict,
    image_dir: pathlib.Path,
    public_base_url: str | None,
):
    image_url = str(card.get("card_image", "")).strip()
    if not image_url or image_url.lower() == "none":
        return None

    image_path = image_path_for(card, image_dir)
    raw_bytes = load_image_bytes(image_url, image_path)
    try:
        image = Image.open(io.BytesIO(raw_bytes)).convert("RGB")
    except Exception:
        image_path.unlink(missing_ok=True)
        raise
    served_url = (
        f"{public_base_url.rstrip('/')}/{image_path.relative_to(image_dir).as_posix()}"
        if public_base_url
        else image_url
    )

    art_crop = crop_box(image, 0.08, 0.08, 0.92, 0.78)
    footer_crop = crop_box(image, 0.05, 0.74, 0.95, 0.98)

    return {
        "code": str(card.get("card_set_id", "")).strip().upper(),
        "name": str(card.get("card_name", "")).strip(),
        "imageUrl": served_url,
        "setName": str(card.get("set_name", "")).strip(),
        "rarity": str(card.get("rarity", "")).strip(),
        "color": str(card.get("card_color", "")).strip(),
        "type": str(card.get("card_type", "")).strip(),
        "fullHash": dhash(image),
        "artHash": dhash(art_crop),
        "footerHash": dhash(footer_crop),
        "avgRgb": average_rgb(image),
    }


def parse_args():
    parser = argparse.ArgumentParser(
        description="Build the local visual card catalog and cache source images."
    )
    parser.add_argument("--output", type=pathlib.Path, default=OUTPUT_PATH)
    parser.add_argument("--image-dir", type=pathlib.Path, default=DEFAULT_IMAGE_DIR)
    parser.add_argument(
        "--public-base-url",
        help="Optional CDN prefix used in generated imageUrl fields.",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=6,
        help="Number of parallel image downloads and fingerprint workers.",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    all_cards = []
    seen = set()

    for url in API_URLS:
        for card in fetch_json(url):
            code = str(card.get("card_set_id", "")).strip().upper()
            image_url = str(card.get("card_image", "")).strip()
            if image_url.lower() == "none":
                image_url = ""
            key = (code, image_url)
            if not code or not image_url or key in seen:
                continue
            seen.add(key)
            all_cards.append(card)

    output = []
    total = len(all_cards)

    def process_card(card: dict):
        code = str(card.get("card_set_id", "")).strip().upper()
        try:
            return (
                code,
                build_fingerprint(
                    card,
                    image_dir=args.image_dir,
                    public_base_url=args.public_base_url,
                ),
                None,
            )
        except Exception as exc:
            return code, None, exc

    with concurrent.futures.ThreadPoolExecutor(
        max_workers=max(1, args.workers)
    ) as executor:
        for index, (code, fingerprint, error) in enumerate(
            executor.map(process_card, all_cards),
            start=1,
        ):
            if error is not None:
                print(f"[skip] {code}: {error}")
            elif fingerprint is not None:
                output.append(fingerprint)
            if index % 50 == 0 or index == total:
                print(f"[{index}/{total}] processed {code}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(output, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"cached source images under {args.image_dir}")
    print(f"saved {len(output)} fingerprints to {args.output}")


if __name__ == "__main__":
    main()
