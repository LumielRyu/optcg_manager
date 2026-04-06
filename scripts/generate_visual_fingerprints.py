import io
import json
import math
import pathlib
import urllib.request

from PIL import Image, ImageOps


API_URLS = [
    "https://www.optcgapi.com/api/allSetCards/?format=json",
    "https://www.optcgapi.com/api/allSTCards/?format=json",
    "https://www.optcgapi.com/api/allPromos/?format=json",
]

OUTPUT_PATH = pathlib.Path("assets/visual_card_fingerprints.json")


def fetch_json(url: str):
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)


def load_image_bytes(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


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
    pixels = list(resized.getdata())
    total = len(pixels) or 1
    r = sum(pixel[0] for pixel in pixels) // total
    g = sum(pixel[1] for pixel in pixels) // total
    b = sum(pixel[2] for pixel in pixels) // total
    return [r, g, b]


def build_fingerprint(card: dict):
    image_url = str(card.get("card_image", "")).strip()
    if not image_url:
        return None

    raw_bytes = load_image_bytes(image_url)
    image = Image.open(io.BytesIO(raw_bytes)).convert("RGB")

    art_crop = crop_box(image, 0.08, 0.08, 0.92, 0.78)
    footer_crop = crop_box(image, 0.05, 0.74, 0.95, 0.98)

    return {
        "code": str(card.get("card_set_id", "")).strip().upper(),
        "name": str(card.get("card_name", "")).strip(),
        "imageUrl": image_url,
        "setName": str(card.get("set_name", "")).strip(),
        "color": str(card.get("card_color", "")).strip(),
        "type": str(card.get("card_type", "")).strip(),
        "fullHash": dhash(image),
        "artHash": dhash(art_crop),
        "footerHash": dhash(footer_crop),
        "avgRgb": average_rgb(image),
    }


def main():
    all_cards = []
    seen = set()

    for url in API_URLS:
        for card in fetch_json(url):
            code = str(card.get("card_set_id", "")).strip().upper()
            image_url = str(card.get("card_image", "")).strip()
            key = (code, image_url)
            if not code or not image_url or key in seen:
                continue
            seen.add(key)
            all_cards.append(card)

    output = []
    total = len(all_cards)

    for index, card in enumerate(all_cards, start=1):
        code = str(card.get("card_set_id", "")).strip().upper()
        try:
            fingerprint = build_fingerprint(card)
            if fingerprint is not None:
                output.append(fingerprint)
            if index % 50 == 0 or index == total:
                print(f"[{index}/{total}] processed {code}")
        except Exception as exc:
            print(f"[skip] {code}: {exc}")

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(
        json.dumps(output, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"saved {len(output)} fingerprints to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
