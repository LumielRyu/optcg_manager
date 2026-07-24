import argparse
import json
import pathlib
import shutil
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]


def executable(*names: str) -> str:
    for name in names:
        path = shutil.which(name)
        if path:
            return path
    raise RuntimeError(f"Executavel nao encontrado: {' / '.join(names)}")


def run(command: list[str]) -> None:
    print(f"\n>> {' '.join(command)}", flush=True)
    result = subprocess.run(command, cwd=ROOT, check=False)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def validate_json_files() -> None:
    files = [
        ROOT / "package.json",
        ROOT / "vercel.json",
        ROOT / "web" / "manifest.json",
    ]
    for path in files:
        with path.open(encoding="utf-8") as source:
            json.load(source)
        print(f"JSON valido: {path.relative_to(ROOT)}")


def validate_api_syntax(node: str) -> None:
    paths = list((ROOT / "api").rglob("*.js"))
    paths.extend((ROOT / "server").rglob("*.js"))
    paths.extend((ROOT / "scripts").glob("*.js"))
    for path in sorted(paths):
        run([node, "--check", str(path)])


def validate_python_syntax() -> None:
    for path in sorted((ROOT / "scripts").glob("*.py")):
        source = path.read_text(encoding="utf-8")
        compile(source, str(path), "exec")
        print(f"Python valido: {path.relative_to(ROOT)}")


def run_python_tests(python: str) -> None:
    tests = sorted((ROOT / "test").glob("test_*.py"))
    if tests:
        run(
            [
                python,
                "-m",
                "unittest",
                "discover",
                "-s",
                str(ROOT / "test"),
                "-p",
                "test_*.py",
            ]
        )


def run_node_tests(node: str) -> None:
    tests = sorted((ROOT / "test").glob("*.test.js"))
    if tests:
        run([node, "--test", *[str(path) for path in tests]])


def validate_coverage(minimum: float) -> None:
    coverage_path = ROOT / "coverage" / "lcov.info"
    if not coverage_path.exists():
        raise RuntimeError("coverage/lcov.info nao foi gerado.")

    lines_found = 0
    lines_hit = 0
    for line in coverage_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("LF:"):
            lines_found += int(line[3:])
        elif line.startswith("LH:"):
            lines_hit += int(line[3:])

    percentage = (lines_hit * 100 / lines_found) if lines_found else 0
    print(
        f"Cobertura de linhas: {lines_hit}/{lines_found} "
        f"({percentage:.2f}%, minimo {minimum:.2f}%)"
    )
    if percentage < minimum:
        raise SystemExit(
            f"Cobertura abaixo do minimo: {percentage:.2f}% < {minimum:.2f}%"
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Executa o quality gate reproduzivel do OPTCG BH."
    )
    parser.add_argument(
        "--coverage",
        action="store_true",
        help="Gera coverage/lcov.info durante os testes.",
    )
    parser.add_argument(
        "--build",
        action="store_true",
        help="Tambem gera o build web de producao.",
    )
    parser.add_argument(
        "--min-coverage",
        type=float,
        default=None,
        help="Falha se a cobertura de linhas ficar abaixo deste percentual.",
    )
    args = parser.parse_args()

    flutter = executable("flutter", "flutter.bat")
    node = executable("node", "node.exe")
    python = sys.executable

    validate_json_files()
    validate_api_syntax(node)
    validate_python_syntax()
    run_python_tests(python)
    run_node_tests(node)
    run([flutter, "analyze", "--fatal-infos", "--fatal-warnings"])

    test_command = [flutter, "test"]
    if args.coverage:
        test_command.append("--coverage")
    run(test_command)
    if args.min_coverage is not None:
        if not args.coverage:
            parser.error("--min-coverage exige --coverage")
        validate_coverage(args.min_coverage)

    if args.build:
        run([python, str(ROOT / "scripts" / "build_web_public_env.py")])
        required_build_files = [
            ROOT / "build" / "web" / "index.html",
            ROOT / "build" / "web" / "main.dart.js",
            ROOT / "build" / "web" / "manifest.json",
            ROOT / "build" / "web" / "robots.txt",
            ROOT / "build" / "web" / "sitemap.xml",
            ROOT / "build" / "web" / "pwa_service_worker.js",
        ]
        missing = [path for path in required_build_files if not path.exists()]
        if missing:
            print("Arquivos ausentes no build:", file=sys.stderr)
            for path in missing:
                print(f"- {path.relative_to(ROOT)}", file=sys.stderr)
            return 1

    print("\nQuality gate aprovado.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
