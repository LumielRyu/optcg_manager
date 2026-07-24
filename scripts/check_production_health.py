import argparse
import json
import urllib.error
import urllib.request


def request(url: str) -> tuple[int, dict[str, str], bytes]:
    headers = {"User-Agent": "OPTCG-BH-Health-Monitor/1.0"}
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            return response.status, dict(response.headers.items()), response.read()
    except urllib.error.HTTPError as error:
        return error.code, dict(error.headers.items()), error.read()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def main() -> int:
    parser = argparse.ArgumentParser(description="Checks the OPTCG BH production app.")
    parser.add_argument("--url", default="https://optcgbh.vercel.app")
    args = parser.parse_args()
    base_url = args.url.rstrip("/")

    status, headers, _ = request(f"{base_url}/")
    require(status == 200, f"Homepage returned HTTP {status}")
    require("max-age=" in headers.get("Strict-Transport-Security", ""), "HSTS missing")
    require("default-src" in headers.get("Content-Security-Policy", ""), "CSP missing")

    status, _, body = request(f"{base_url}/api/health")
    require(status == 200, f"Health endpoint returned HTTP {status}: {body[:300]!r}")
    payload = json.loads(body)
    require(payload.get("status") == "ok", f"Health is degraded: {payload}")

    print(
        json.dumps(
            {
                "status": "ok",
                "url": base_url,
                "release": payload.get("release"),
                "checks": payload.get("checks"),
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
