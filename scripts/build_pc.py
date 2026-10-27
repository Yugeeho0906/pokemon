#!/usr/bin/env python3
"""Godot PC 게임·편집용 프로젝트 ZIP을 재현 가능하게 만든다."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"
VERSION = "4.6.3"
TEMPLATE_VERSION = f"{VERSION}.stable"
TEMPLATE_ARCHIVE = f"Godot_v{VERSION}-stable_export_templates.tpz"
RELEASE_URL = f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable"
# 공식 SHA512-SUMS.txt에서 확인한 비-Mono 내보내기 템플릿의 해시.
TEMPLATE_SHA512 = "da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68"
TEMPLATE_FILES = (
    "version.txt",
    "linux_debug.x86_64",
    "linux_release.x86_64",
    "windows_debug_x86_64.exe",
    "windows_release_x86_64.exe",
    "windows_debug_x86_64_console.exe",
    "windows_release_x86_64_console.exe",
)


def digest_file(path: Path, algorithm: str = "sha256") -> str:
    digest = hashlib.new(algorithm)
    with path.open("rb") as source:
        for block in iter(lambda: source.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def download_verified_archive(cache: Path) -> Path:
    archive = cache / TEMPLATE_ARCHIVE
    cache.mkdir(parents=True, exist_ok=True)
    if not archive.exists():
        partial = archive.with_suffix(".tpz.download")
        print("공식 Godot 내보내기 템플릿을 다운로드합니다.", flush=True)
        with urllib.request.urlopen(f"{RELEASE_URL}/{TEMPLATE_ARCHIVE}", timeout=90) as response:
            with partial.open("wb") as target:
                shutil.copyfileobj(response, target, 8 * 1024 * 1024)
        if digest_file(partial, "sha512") != TEMPLATE_SHA512:
            partial.unlink(missing_ok=True)
            raise RuntimeError("공식 템플릿의 SHA512가 일치하지 않아 사용하지 않습니다.")
        partial.replace(archive)
    elif digest_file(archive, "sha512") != TEMPLATE_SHA512:
        raise RuntimeError(f"기존 템플릿의 SHA512가 일치하지 않습니다: {archive}")
    return archive


def prepare_templates(cache: Path) -> tuple[Path, Path]:
    """공식 검증을 마친 Windows/Linux x86_64 템플릿만 설치한다."""
    data_root = cache.parent / "data"
    target = data_root / "godot" / "export_templates" / TEMPLATE_VERSION
    manifest_path = target / "verified-files.json"
    if manifest_path.is_file():
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            hashes = manifest["sha256"]
            valid = manifest["archive_sha512"] == TEMPLATE_SHA512 and all(
                (target / name).is_file() and digest_file(target / name) == hashes[name]
                for name in TEMPLATE_FILES
            )
            if valid:
                print(f"검증된 내보내기 템플릿: {target}", flush=True)
                return target, data_root
        except (OSError, ValueError, KeyError, TypeError):
            pass

    archive = download_verified_archive(cache)
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as source:
        for name in TEMPLATE_FILES:
            destination = target / name
            with source.open(f"templates/{name}") as content, destination.open("wb") as output:
                shutil.copyfileobj(content, output, 8 * 1024 * 1024)
            if name.startswith("linux_"):
                destination.chmod(0o755)
    if (target / "version.txt").read_text(encoding="utf-8").strip() != TEMPLATE_VERSION:
        raise RuntimeError("템플릿 버전이 편집기 버전과 다릅니다.")
    manifest = {"archive_sha512": TEMPLATE_SHA512, "sha256": {name: digest_file(target / name) for name in TEMPLATE_FILES}}
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"공식 SHA512 검증 및 템플릿 준비 완료: {target}", flush=True)
    return target, data_root


def run_checked(command: list[str], environment: dict[str, str], label: str) -> None:
    result = subprocess.run(command, cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log_directory = DIST / "build_logs"
    log_directory.mkdir(parents=True, exist_ok=True)
    (log_directory / f"{label}.log").write_text(result.stdout, encoding="utf-8")
    if result.returncode != 0 or "ERROR:" in result.stdout or "Parse Error:" in result.stdout:
        print(result.stdout[-12000:], file=sys.stderr)
        raise RuntimeError(f"{label} 실패. 로그: {log_directory / (label + '.log')}")
    print(f"통과: {label}", flush=True)


def add_to_zip(archive: zipfile.ZipFile, path: Path, name: str, executable: bool = False) -> None:
    info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = (0o100755 if executable else 0o100644) << 16
    with archive.open(info, "w") as output, path.open("rb") as source:
        shutil.copyfileobj(source, output, 8 * 1024 * 1024)


def prepare_licenses(cache: Path) -> list[Path]:
    paths = []
    for source_name, destination_name in (("LICENSE.txt", "Godot-LICENSE.txt"), ("COPYRIGHT.txt", "Godot-COPYRIGHT.txt")):
        destination = cache / destination_name
        if not destination.is_file():
            url = f"https://raw.githubusercontent.com/godotengine/godot/{VERSION}-stable/{source_name}"
            with urllib.request.urlopen(url, timeout=60) as response:
                content = response.read()
            if len(content) < 100:
                raise RuntimeError(f"공식 Godot 라이선스 파일이 비정상적입니다: {source_name}")
            destination.write_bytes(content)
        paths.append(destination)
    return paths


def package_game(platform: str, folder: Path, filename: str, licenses: list[Path]) -> Path:
    label = "Windows" if platform == "windows" else "Linux"
    instructions = f"""포켓몬스터: 천년의 전설 — {label} x86_64 체험판

ZIP을 모두 압축 해제한 뒤 {filename}을 실행하세요.
별도의 Godot 편집기 설치는 필요 없습니다. Linux는 실행 권한이 없으면 chmod +x 명령으로 지정하세요.
이 ZIP을 카카오톡 '나와의 채팅'에 파일로 첨부하면 보관할 수 있습니다.
카카오톡 미리보기 안에서 실행하는 파일은 아닙니다.

진행 상황은 게임의 저장/불러오기 메뉴에서 관리합니다.
기본 저장은 Godot user:// 사용자 데이터 폴더에 기록됩니다.
기기를 옮길 때는 저장 데이터를 JSON으로 내보내고 게임 ZIP과 함께 보관하세요.
이 파일을 실행하면 게임 파일과 저장 데이터가 PC에 남습니다.
회사 기기의 보안·실행 정책을 따르세요. 기록이 남지 않는다고 보장하지 않습니다.

현재 제작 범위는 인천 프롤로그부터 수원 첫 체육관까지입니다.
전체 지역·8체육관·사천왕·챔피언·2부·인연 이벤트 전체가 완성된 게임은 아닙니다.
세부 구현 상태와 검증 결과는 함께 제공한 README.md를 확인하세요.
"""
    (folder / "먼저읽기.txt").write_text(instructions, encoding="utf-8")
    shutil.copy2(ROOT / "README.md", folder / "README.md")
    for path in licenses:
        shutil.copy2(path, folder / path.name)
    font_license = ROOT / "assets" / "fonts" / "LICENSE.txt"
    if font_license.is_file():
        shutil.copy2(font_license, folder / "NotoSansKR-LICENSE.txt")
    output = DIST / f"천년의전설_{label}_게임.zip"
    entries = [folder / filename, folder / "먼저읽기.txt", folder / "README.md"]
    entries.extend(folder / path.name for path in licenses)
    if font_license.is_file():
        entries.append(folder / "NotoSansKR-LICENSE.txt")
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(entries):
            add_to_zip(archive, path, path.name, platform == "linux" and path.name == filename)
    return output


def package_source() -> Path:
    root_names = ("project.godot", "export_presets.cfg", "README.md", ".gitignore")
    paths = [ROOT / name for name in root_names]
    allowed = {".gd", ".uid", ".import", ".tscn", ".tres", ".gdshader", ".gdextension", ".json", ".md", ".txt", ".py", ".sh", ".webp", ".png", ".svg", ".jpg", ".jpeg", ".ttf", ".otf", ".wav", ".ogg", ".mjs", ".js", ".css", ".html", ".cfg"}
    for name in ("game", "scenes", "assets", "docs", "scripts", "tests", "reference", "prototypes"):
        folder = ROOT / name
        if folder.exists():
            for path in folder.rglob("*"):
                excluded = {"__pycache__", ".git", ".godot", "node_modules", "dist", "test-results", "screenshots", "saves"}
                if not path.is_file() or path.suffix not in allowed or excluded.intersection(path.relative_to(ROOT).parts):
                    continue
                if name == "tests" and path.suffix not in {".gd", ".uid", ".py"}:
                    continue
                if path.suffix == ".json" and path != ROOT / "game" / "data.json" and path.name not in {"package.json", "package-lock.json"}:
                    continue
                paths.append(path)
    output = DIST / "천년의전설_Godot_프로젝트.zip"
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(set(paths)):
            if not path.is_file() or path.is_symlink() or not path.resolve().is_relative_to(ROOT):
                raise RuntimeError(f"프로젝트 경로를 확인하세요: {path}")
            add_to_zip(archive, path, f"pokemon/{path.relative_to(ROOT).as_posix()}", path.suffix == ".sh")
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description="Godot 4.6.3 Windows/Linux 게임과 프로젝트 ZIP 빌드")
    parser.add_argument("--godot", default=shutil.which("godot") or "godot")
    parser.add_argument("--platform", choices=("both", "windows", "linux"), default="both")
    parser.add_argument("--cache-dir", type=Path, default=Path(os.environ.get("POKEMON_TOOLCHAIN_DIR", str(ROOT.parent / "toolchains" / "godot" / VERSION))))
    parser.add_argument("--templates-only", action="store_true", help="검증된 공식 내보내기 템플릿만 준비")
    args = parser.parse_args()
    _, data_root = prepare_templates(args.cache_dir.resolve())
    if args.templates_only:
        return
    if not (ROOT / "project.godot").is_file():
        raise RuntimeError("project.godot이 없습니다. 프로젝트 생성 후 다시 실행하세요.")
    environment = dict(os.environ)
    environment["XDG_DATA_HOME"] = str(data_root)
    environment["XDG_CACHE_HOME"] = str(args.cache_dir.resolve().parent / "cache")
    environment["XDG_CONFIG_HOME"] = str(args.cache_dir.resolve().parent / "config")
    Path(environment["XDG_CACHE_HOME"]).mkdir(parents=True, exist_ok=True)
    Path(environment["XDG_CONFIG_HOME"]).mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([args.godot, "--version"], env=environment, text=True).strip()
    if not version.startswith(f"{VERSION}.stable"):
        raise RuntimeError(f"Godot {VERSION}.stable 편집기가 필요합니다. 현재: {version}")
    DIST.mkdir(parents=True, exist_ok=True)
    licenses = prepare_licenses(args.cache_dir.resolve())
    run_checked([args.godot, "--headless", "--path", str(ROOT), "--editor", "--import", "--quit"], environment, "import")
    outputs = []
    platforms = ("windows", "linux") if args.platform == "both" else (args.platform,)
    for platform in platforms:
        folder = DIST / platform
        folder.mkdir(parents=True, exist_ok=True)
        filename = "천년의전설.exe" if platform == "windows" else "천년의전설.x86_64"
        preset = "Windows Desktop" if platform == "windows" else "Linux Desktop"
        executable = folder / filename
        run_checked([args.godot, "--headless", "--path", str(ROOT), "--export-release", preset, str(executable)], environment, f"export_{platform}")
        if not executable.is_file() or executable.stat().st_size < 1_000_000:
            raise RuntimeError(f"내보낸 실행 파일이 없거나 비정상적으로 작습니다: {executable}")
        if platform == "linux" and sys.platform.startswith("linux"):
            executable.chmod(0o755)
            run_checked([str(executable), "--headless", "--quit-after", "3"], environment, "runtime_linux")
        outputs.append(package_game(platform, folder, filename, licenses))
    outputs.append(package_source())
    for path in outputs:
        print(f"{path.relative_to(ROOT)} ({path.stat().st_size:,} bytes)")
    print("Windows 실행 검증은 Windows PC에서 별도로 필요합니다.")


if __name__ == "__main__":
    main()
