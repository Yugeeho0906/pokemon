#!/usr/bin/env bash
# 클라우드에서는 편집기 설정과 캐시를 쓰기 가능한 작업 공간에 보관합니다.
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
toolchain_root="${POKEMON_TOOLCHAIN_ROOT:-$(dirname -- "$project_root")/toolchains/godot}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$toolchain_root/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$toolchain_root/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$toolchain_root/cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"

exec "${GODOT_BIN:-godot}" --path "$project_root" "$@"
