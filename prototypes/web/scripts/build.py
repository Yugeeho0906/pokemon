#!/usr/bin/env python3
"""외부 도구 없이 코드와 일러스트를 단일 오프라인 HTML로 묶는다."""

from __future__ import annotations

import base64
import mimetypes
import re
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "dist"
GAME_NAME = "천년의전설"
ASSET_PATTERN = re.compile(r"(?<![\w/])(?:\./)?assets/[A-Za-z0-9_./-]+\.webp")


def read_text(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


def wrap_module(relative_path: str, namespace: str) -> str:
    """이 프로젝트의 이름 있는 ES 모듈을 독립 함수 범위로 묶는다."""
    source = read_text(relative_path)
    exports = re.findall(
        r"^export\s+(?:async\s+)?(?:function|class|const|let|var)\s+([A-Za-z_$][\w$]*)",
        source,
        re.MULTILINE,
    )
    aliases = []

    def collect_export_list(match: re.Match[str]) -> str:
        for item in match.group(1).split(","):
            item = item.strip()
            if not item:
                continue
            parts = re.split(r"\s+as\s+", item)
            if any(not re.fullmatch(r"[A-Za-z_$][\w$]*", part) for part in parts):
                raise ValueError(f"지원하지 않는 export: {item}")
            aliases.append(parts[0] if len(parts) == 1 else f"{parts[1]}: {parts[0]}")
        return ""

    source = re.sub(r"^export\s*\{([^}]+)\}\s*;?", collect_export_list, source, flags=re.MULTILINE)
    source = re.sub(r"^export\s+", "", source, flags=re.MULTILINE)
    if re.search(r"^\s*(?:import\s|export\s|default\s)", source, re.MULTILINE):
        raise ValueError(f"독립 번들로 변환할 수 없는 모듈 문법: {relative_path}")
    names = list(dict.fromkeys(exports + aliases))
    if not names:
        raise ValueError(f"내보내는 함수가 없는 모듈: {relative_path}")
    return f"const {namespace} = (() => {{\n{source}\nreturn {{ {', '.join(names)} }};\n}})();\n"


def embed_assets(text: str) -> str:
    """참조한 원본 WebP 바이트를 변형 없이 data URL에 포함한다."""
    assets_root = (ROOT / "assets").resolve()
    cache: dict[str, str] = {}

    def replace(match: re.Match[str]) -> str:
        relative = match.group(0).removeprefix("./")
        if relative not in cache:
            path = (ROOT / relative).resolve()
            if not path.is_relative_to(assets_root) or not path.is_file():
                raise ValueError(f"일러스트 파일을 찾을 수 없습니다: {relative}")
            mime_type = mimetypes.guess_type(path.name)[0] or "image/webp"
            cache[relative] = f"data:{mime_type};base64,{base64.b64encode(path.read_bytes()).decode('ascii')}"
        return cache[relative]

    return ASSET_PATTERN.sub(replace, text)


def create_html() -> str:
    html = read_text("index.html")
    css = read_text("src/style.css")
    app = read_text("src/app.mjs")
    modules = (("Engine", "engine"), ("World", "world"), ("Art", "creature-art"))
    for namespace, filename in modules:
        pattern = rf"^import\s+\*\s+as\s+{namespace}\s+from\s+['\"]\./{filename}\.mjs['\"]\s*;?\s*$"
        app, count = re.subn(pattern, "", app, flags=re.MULTILINE)
        if count != 1:
            raise ValueError(f"예상한 {namespace} 모듈 import가 없습니다.")
    if re.search(r"^\s*import\s", app, re.MULTILINE):
        raise ValueError("오프라인 번들에 처리하지 못한 import가 남아 있습니다.")

    script = "".join(wrap_module(f"src/{filename}.mjs", namespace) for namespace, filename in modules) + app
    script = re.sub(r"</script", r"<\\/script", script, flags=re.IGNORECASE)
    html, css_count = re.subn(
        r'<link\s+rel="stylesheet"\s+href="\./src/style\.css"\s*/?>',
        lambda _: f"<style>\n{css}\n</style>",
        html,
    )
    html, script_count = re.subn(
        r'<script\s+type="module"\s+src="\./src/app\.mjs"\s*>\s*</script>',
        lambda _: f'<script type="module">\n{script}\n</script>',
        html,
    )
    if (css_count, script_count) != (1, 1):
        raise ValueError("index.html의 stylesheet/script 태그를 확인하세요.")
    return embed_assets(html)


def write_zip(path: Path, entries: list[tuple[str, bytes]]) -> None:
    """입력 순서와 타임스탬프를 고정하여 같은 소스로 같은 ZIP을 만든다."""
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, contents in entries:
            info = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, contents)


def collect_source() -> list[tuple[str, bytes]]:
    # 명시한 프로젝트 파일만 수집한다. Git 메타데이터와 사용자 저장 파일은 제외한다.
    files = [ROOT / name for name in ("index.html", "package.json", ".gitignore", "README.md")]
    extensions = {"src": {".mjs", ".css"}, "assets": {".webp"}, "scripts": {".py"}, "docs": {".md"}, "tests": {".mjs"}}
    for directory, suffixes in extensions.items():
        folder = ROOT / directory
        if folder.exists():
            files.extend(path for path in folder.rglob("*") if path.is_file() and path.suffix in suffixes)
    entries = []
    for path in sorted(set(files)):
        if not path.exists() or path.is_symlink() or not path.resolve().is_relative_to(ROOT):
            raise ValueError(f"안전하게 묶을 수 없는 소스 경로: {path.name}")
        entries.append((f"pokemon/{path.relative_to(ROOT).as_posix()}", path.read_bytes()))
    return entries


def main() -> None:
    html = create_html().encode("utf-8")
    usage = """포켓몬스터: 천년의 전설 — 인천·수원 체험판

1. 천년의전설.html을 Chrome 또는 Edge에서 여세요. 별도 설치가 필요 없습니다.
2. 카카오톡 '나와의 채팅'에는 HTML이나 게임 ZIP을 파일로 첨부해 보관하세요.
3. 다른 기기에서는 파일을 내려받아 여세요. 카카오톡 내부 미리보기에서는 실행되지 않을 수 있습니다.
4. 진행 상황은 게임의 저장 메뉴에서 브라우저에 저장하거나 JSON 파일로 내보낼 수 있습니다.
5. 이어할 때 같은 브라우저에서 저장을 불러오거나 내보낸 JSON 파일을 가져오세요.
6. 게임 파일과 저장 JSON은 별개입니다. 다른 기기로 옮길 때는 둘 다 보관하세요.

현재 범위: 인천 프롤로그, 특별한 이로치 랄토스 구조, 스타팅 선택,
필드 탐험, 야생 전투·포획, 수원 첫 체육관.
이후 지역, 전체 포켓몬 도감, 진화·메가진화, 사천왕·챔피언·2부는 아직 구현되지 않았습니다.
전투 밸런스와 세부 대사는 플레이 검증용이며 최종 설정 확정안이 아닙니다.
스타팅·랄토스·일반 야생 포켓몬의 전투 그림은 임시 벡터 표현입니다.
대여르·드레디어·한국풍 메가가디안의 최신 승인 원본은 설정집 갤러리에서 확인할 수 있습니다.

브라우저 저장은 기기와 브라우저별로 분리되며, 파일 위치나 브라우저 설정에 따라 접근하지 못할 수 있습니다.
브라우저 기록·캐시 및 회사 보안 시스템의 접속 기록이 남지 않는다고 보장하지 않습니다.
"""
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / f"{GAME_NAME}.html").write_bytes(html)
    write_zip(OUTPUT / f"{GAME_NAME}_게임.zip", [(f"{GAME_NAME}.html", html), ("먼저읽기.txt", usage.encode("utf-8"))])
    write_zip(OUTPUT / f"{GAME_NAME}_소스.zip", collect_source())
    for path in sorted(OUTPUT.glob(f"{GAME_NAME}*")):
        print(f"{path.relative_to(ROOT)} ({path.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
