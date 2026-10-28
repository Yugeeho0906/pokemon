#!/usr/bin/env python3
"""Build a reusable 1–9 generation Pokémon battle-sprite catalog from PokeAPI/Sprites.

The catalog contains national-dex 1..1025 plus every PokeAPI Pokémon resource whose
name includes '-mega'. It deliberately keeps original 96px transparent PNGs rather
than AI-generating lookalikes. Custom project species remain in the registry but use
project-owned generated assets.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
API_URL = "https://pokeapi.co/api/v2/pokemon?limit=10000"
RAW_ROOT = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"
MAX_GEN9_DEX = 1025
GENERATION_RANGES = ((1, 151, 1), (152, 251, 2), (252, 386, 3), (387, 493, 4), (494, 649, 5), (650, 721, 6), (722, 809, 7), (810, 905, 8), (906, 1025, 9))
# PokeAPI index에는 있으나 스프라이트 저장소에 앞·뒤 원본이 없는 비정규 항목입니다.
EXCLUDED_UNAVAILABLE_FORMS = {"zygarde-mega"}


def fetch(url: str, attempts: int = 3) -> bytes | None:
    request = Request(url, headers={"User-Agent": "PokemonCodexSpriteSync/1.0"})
    for attempt in range(attempts):
        try:
            with urlopen(request, timeout=30) as response:
                if response.status == 200:
                    return response.read()
        except HTTPError as exc:
            if exc.code == 404:
                return None
        except URLError:
            pass
        time.sleep(0.4 * (attempt + 1))
    return None


def pokemon_id(item: dict) -> int:
    return int(str(item["url"]).rstrip("/").split("/")[-1])


def generation(dex: int) -> int:
    for first, last, value in GENERATION_RANGES:
        if first <= dex <= last:
            return value
    return 9


def sprite_urls(resource_id: int, pose: str) -> list[str]:
    prefix = f"{RAW_ROOT}/versions/generation-v/black-white"
    if pose == "back":
        return [f"{prefix}/back/{resource_id}.png", f"{RAW_ROOT}/back/{resource_id}.png"]
    return [f"{prefix}/{resource_id}.png", f"{RAW_ROOT}/{resource_id}.png"]


def download_sprite(entry: dict, pose: str, out_dir: Path) -> tuple[str, str, bool]:
    destination = out_dir / entry["slug"] / f"{pose}.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_file() and destination.stat().st_size > 0:
        return entry["slug"], pose, True
    for url in sprite_urls(entry["resource_id"], pose):
        payload = fetch(url)
        if payload is not None:
            destination.write_bytes(payload)
            return entry["slug"], pose, True
    return entry["slug"], pose, False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "assets" / "catalog" / "pokemon")
    parser.add_argument("--workers", type=int, default=12)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=0, help="Only sync this many canonical entries; use for a fast smoke test.")
    args = parser.parse_args()

    payload = fetch(API_URL)
    if payload is None:
        print("Unable to retrieve PokeAPI Pokémon index.", file=sys.stderr)
        return 1
    index = json.loads(payload)
    resources = [{"slug": item["name"], "resource_id": pokemon_id(item)} for item in index["results"]]
    canonical = [item for item in resources if 1 <= item["resource_id"] <= MAX_GEN9_DEX]
    canonical.sort(key=lambda item: item["resource_id"])
    if len(canonical) != MAX_GEN9_DEX:
        print(f"Expected {MAX_GEN9_DEX} canonical entries, received {len(canonical)}.", file=sys.stderr)
        return 1
    if args.limit:
        canonical = canonical[: args.limit]
    for item in canonical:
        item.update({"kind": "canonical", "dex": item["resource_id"], "generation": generation(item["resource_id"])})

    megas = [item for item in resources if "-mega" in item["slug"] and item["slug"] not in EXCLUDED_UNAVAILABLE_FORMS]
    megas.sort(key=lambda item: item["resource_id"])
    for item in megas:
        item.update({"kind": "mega", "dex": None, "generation": None})

    output = args.output.resolve()
    entries = canonical + megas
    if args.dry_run:
        print(f"DRY_RUN canonical={len(canonical)} mega={len(megas)} files={len(entries) * 2} output={output}")
        return 0

    output.mkdir(parents=True, exist_ok=True)
    failures: list[str] = []
    futures = []
    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as executor:
        for entry in entries:
            for pose in ("front", "back"):
                futures.append(executor.submit(download_sprite, entry, pose, output))
        completed = 0
        total = len(futures)
        for future in as_completed(futures):
            slug, pose, ok = future.result()
            completed += 1
            if not ok:
                failures.append(f"{slug}/{pose}.png")
            if completed % 100 == 0 or completed == total:
                print(f"SYNC_PROGRESS completed={completed}/{total} failed={len(failures)}", flush=True)

    custom_entries = [
        {"slug": "purunae", "kind": "custom_starter", "stage": 1, "generation": "original", "sprites": {"front": "../generated/battle/purunae_front.png", "back": "../generated/battle/purunae_back.png"}},
        {"slug": "purusori", "kind": "custom_starter", "stage": 2, "generation": "original", "sprites": {"front": "../generated/battle/purusori_front.png", "back": "../generated/battle/purusori_back.png"}},
        {"slug": "ulchangryeong", "kind": "custom_starter", "stage": 3, "generation": "original", "sprites": {"front": "../generated/battle/ulchangryeong_front.png", "back": "../generated/battle/ulchangryeong_back.png"}},
        {"slug": "hwarangi", "kind": "custom_starter", "stage": 1, "generation": "original", "sprites": {"front": "../generated/battle/hwarangi_front.png", "back": "../generated/battle/hwarangi_back.png"}},
        {"slug": "bulhoryeong", "kind": "custom_starter", "stage": 2, "generation": "original", "sprites": {"front": "../generated/battle/bulhoryeong_front.png", "back": "../generated/battle/bulhoryeong_back.png"}},
        {"slug": "jinhwarang", "kind": "custom_starter", "stage": 3, "generation": "original", "sprites": {"front": "../generated/battle/jinhwarang_front.png", "back": "../generated/battle/jinhwarang_back.png"}},
        {"slug": "padoring", "kind": "custom_starter", "stage": 1, "generation": "original", "sprites": {"front": "../generated/battle/padoring_front.png", "back": "../generated/battle/padoring_back.png"}},
        {"slug": "mulgyeoldari", "kind": "custom_starter", "stage": 2, "generation": "original", "sprites": {"front": "../generated/battle/mulgyeoldari_front.png", "back": "../generated/battle/mulgyeoldari_back.png"}},
        {"slug": "haeryushin", "kind": "custom_starter", "stage": 3, "generation": "original", "sprites": {"front": "../generated/battle/haeryushin_front.png", "back": "../generated/battle/haeryushin_back.png"}},
        {"slug": "cheonhwagu", "kind": "legendary_guardian", "types": ["fairy", "dark"], "story_only": True, "sprites": {"front": "../generated/battle/cheonhwagu_front.png", "back": "../generated/battle/cheonhwagu_back.png"}},
        {"slug": "cheonhwarin", "kind": "legendary_guardian", "types": ["fairy", "flying"], "story_only": True, "sprites": {"front": "../generated/battle/cheonhwarin_front.png", "back": "../generated/battle/cheonhwarin_back.png"}},
        {"slug": "wolhwarok", "kind": "legendary_guardian", "types": ["grass", "fairy"], "story_only": True, "sprites": {"front": "../generated/battle/wolhwarok_front.png", "back": "../generated/battle/wolhwarok_back.png"}},
        {"slug": "cheonghaeryong", "kind": "legendary_guardian", "types": ["water", "dragon"], "story_only": True, "sprites": {"front": "../generated/battle/cheonghaeryong_front.png", "back": "../generated/battle/cheonghaeryong_back.png"}},
        {"slug": "geumnyeonhwa", "kind": "legendary_guardian", "types": ["ground", "fairy"], "story_only": True, "sprites": {"front": "../generated/battle/geumnyeonhwa_front.png", "back": "../generated/battle/geumnyeonhwa_back.png"}},
        {"slug": "wolhaeryeong", "kind": "legendary_guardian", "types": ["ghost", "water"], "story_only": True, "sprites": {"front": "../generated/battle/wolhaeryeong_front.png", "back": "../generated/battle/wolhaeryeong_back.png"}},
    ]
    custom_entries += [
        {"slug": "ninetales_korean", "kind": "korean_regional_form", "form_of": "ninetales", "types": ["ghost", "fairy"], "story_only": True, "sprites": {"front": "../generated/battle/ninetales_korean_front.png", "back": "../generated/battle/ninetales_korean_back.png"}},
        {"slug": "arcanine_korean", "kind": "korean_regional_form", "form_of": "arcanine", "types": ["fire", "rock"], "story_only": True, "sprites": {"front": "../generated/battle/arcanine_korean_front.png", "back": "../generated/battle/arcanine_korean_back.png"}},
        {"slug": "bronzong_korean", "kind": "korean_regional_form", "form_of": "bronzong", "types": ["steel", "ghost"], "story_only": True, "sprites": {"front": "../generated/battle/bronzong_korean_front.png", "back": "../generated/battle/bronzong_korean_back.png"}},
        {"slug": "lilligant_korean", "kind": "korean_regional_form", "form_of": "lilligant", "types": ["grass", "fairy"], "story_only": True, "sprites": {"front": "../generated/battle/lilligant_korean_front.png", "back": "../generated/battle/lilligant_korean_back.png"}},
        {"slug": "noctowl_korean", "kind": "korean_regional_form", "form_of": "noctowl", "types": ["psychic", "flying"], "story_only": True, "sprites": {"front": "../generated/battle/noctowl_korean_front.png", "back": "../generated/battle/noctowl_korean_back.png"}},
        {"slug": "rapidash_korean", "kind": "korean_regional_form", "form_of": "rapidash", "types": ["water", "fairy"], "story_only": True, "sprites": {"front": "../generated/battle/rapidash_korean_front.png", "back": "../generated/battle/rapidash_korean_back.png"}},
        {"slug": "chimecho_korean", "kind": "korean_regional_form", "form_of": "chimecho", "types": ["psychic", "fairy"], "story_only": True, "sprites": {"front": "../generated/battle/chimecho_korean_front.png", "back": "../generated/battle/chimecho_korean_back.png"}},
        {"slug": "absol_korean", "kind": "korean_regional_form", "form_of": "absol", "types": ["dark", "ice"], "story_only": True, "sprites": {"front": "../generated/battle/absol_korean_front.png", "back": "../generated/battle/absol_korean_back.png"}},
        {"slug": "lucario_korean", "kind": "korean_regional_form", "form_of": "lucario", "types": ["fighting", "steel"], "story_only": True, "sprites": {"front": "../generated/battle/lucario_korean_front.png", "back": "../generated/battle/lucario_korean_back.png"}},
        {"slug": "falinks_korean", "kind": "korean_regional_form", "form_of": "falinks", "types": ["fighting", "steel"], "story_only": True, "sprites": {"front": "../generated/battle/falinks_korean_front.png", "back": "../generated/battle/falinks_korean_back.png"}},
        {"slug": "decidueye_korean", "kind": "korean_regional_form", "form_of": "decidueye", "types": ["grass", "ghost"], "story_only": True, "sprites": {"front": "../generated/battle/decidueye_korean_front.png", "back": "../generated/battle/decidueye_korean_back.png"}},
        {"slug": "milotic_korean", "kind": "korean_regional_form", "form_of": "milotic", "types": ["water", "dragon"], "story_only": True, "sprites": {"front": "../generated/battle/milotic_korean_front.png", "back": "../generated/battle/milotic_korean_back.png"}},
        {"slug": "mega_ulchangryeong", "kind": "custom_mega", "form_of": "ulchangryeong", "types": ["grass", "fairy"], "story_only": True, "sprites": {"front": "../generated/battle/mega_ulchangryeong_front.png", "back": "../generated/battle/mega_ulchangryeong_back.png"}},
        {"slug": "mega_jinhwarang", "kind": "custom_mega", "form_of": "jinhwarang", "types": ["fire", "fighting"], "story_only": True, "sprites": {"front": "../generated/battle/mega_jinhwarang_front.png", "back": "../generated/battle/mega_jinhwarang_back.png"}},
        {"slug": "mega_haeryushin", "kind": "custom_mega", "form_of": "haeryushin", "types": ["water", "dragon"], "story_only": True, "sprites": {"front": "../generated/battle/mega_haeryushin_front.png", "back": "../generated/battle/mega_haeryushin_back.png"}},
        {"slug": "mega_cheonhwagu", "kind": "custom_mega", "form_of": "cheonhwagu", "types": ["fairy", "dark"], "story_only": True, "sprites": {"front": "../generated/battle/mega_cheonhwagu_front.png", "back": "../generated/battle/mega_cheonhwagu_back.png"}},
        {"slug": "mega_gardevoir_korean_shiny", "kind": "custom_mega", "form_of": "gardevoir", "types": ["psychic", "fairy"], "story_only": True, "sprites": {"front": "../generated/battle/mega_gardevoir_korean_shiny_front.png", "back": "../generated/battle/mega_gardevoir_korean_shiny_back.png"}},
    ]
    ready_custom_entries: list[dict] = []
    pending_custom_entries: list[dict] = []
    for entry in custom_entries:
        paths = [output.parent / relative for relative in entry["sprites"].values()]
        (ready_custom_entries if all(path.is_file() for path in paths) else pending_custom_entries).append(entry)
    manifest = {
        "schema": 1,
        "source": {"name": "PokeAPI Sprites", "repository": "https://github.com/PokeAPI/sprites", "style": "Generation V Black/White when available; PokeAPI default only as a fallback"},
        "coverage": {"canonical_national_dex": [1, MAX_GEN9_DEX], "canonical_entries": len(canonical), "mega_entries": len(megas), "failed_files": failures},
        "entries": entries,
        "custom_entries": ready_custom_entries,
        "pending_custom_entries": pending_custom_entries,
    }
    (output.parent / "pokemon_sprite_registry.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"CATALOG_RESULT canonical={len(canonical)} mega={len(megas)} files={len(entries) * 2} failed={len(failures)}")
    if failures:
        print("\n".join(failures[:50]))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
