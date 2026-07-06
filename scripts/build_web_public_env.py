import os
import pathlib
import shutil
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
ENV_PATH = ROOT / ".env"


def load_env_file(path: pathlib.Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def public_value(name: str, file_values: dict[str, str]) -> str:
    return os.environ.get(name, "").strip() or file_values.get(name, "").strip()


def main() -> int:
    file_values = load_env_file(ENV_PATH)
    supabase_url = public_value("SUPABASE_URL", file_values)
    supabase_anon_key = public_value("SUPABASE_ANON_KEY", file_values)

    missing = [
        name
        for name, value in (
            ("SUPABASE_URL", supabase_url),
            ("SUPABASE_ANON_KEY", supabase_anon_key),
        )
        if not value
    ]
    if missing:
        print(
            "Variaveis publicas ausentes para o build web: "
            + ", ".join(missing),
            file=sys.stderr,
        )
        return 1

    flutter_executable = shutil.which("flutter") or shutil.which("flutter.bat")
    if not flutter_executable:
        print("Flutter nao foi encontrado no PATH.", file=sys.stderr)
        return 1

    command = [
        flutter_executable,
        "build",
        "web",
        "--release",
        f"--dart-define=SUPABASE_URL={supabase_url}",
        f"--dart-define=SUPABASE_ANON_KEY={supabase_anon_key}",
    ]

    if os.environ.get("INCLUDE_POKEMON_TCG_API_KEY_IN_WEB", "").lower() == "true":
        pokemon_key = public_value("POKEMON_TCG_API_KEY", file_values)
        if pokemon_key:
            command.append(f"--dart-define=POKEMON_TCG_API_KEY={pokemon_key}")

    print("Gerando build web com variaveis publicas permitidas.")
    return subprocess.call(command, cwd=ROOT)


if __name__ == "__main__":
    raise SystemExit(main())
