#!/usr/bin/env python3
"""Verify the local 1–9 generation and custom battle-sprite registry."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "assets/catalog/pokemon_sprite_registry.json"
CATALOG = ROOT / "assets/catalog/pokemon"


def main() -> int:
    data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    errors: list[str] = []
    coverage = data["coverage"]
    if coverage.get("canonical_entries") != 1025:
        errors.append(f"canonical_entries={coverage.get('canonical_entries')}")
    if coverage.get("failed_files"):
        errors.append("failed_files are recorded")
    canonical = [entry for entry in data["entries"] if entry["kind"] == "canonical"]
    megas = [entry for entry in data["entries"] if entry["kind"] == "mega"]
    custom_starters = [entry for entry in data["custom_entries"] if entry["kind"] == "custom_starter"]
    guardians = [entry for entry in data["custom_entries"] if entry["kind"] == "legendary_guardian"]
    regional_forms = [entry for entry in data["custom_entries"] if entry["kind"] == "korean_regional_form"]
    custom_megas = [entry for entry in data["custom_entries"] if entry["kind"] == "custom_mega"]
    pending_custom = list(data.get("pending_custom_entries", []))
    if len(canonical) != 1025:
        errors.append(f"canonical manifest count={len(canonical)}")
    if not megas:
        errors.append("no mega forms")
    if len(custom_starters) != 9:
        errors.append(f"custom starter-line count={len(custom_starters)}")
    if len(guardians) != 6:
        errors.append(f"legendary guardian count={len(guardians)}")
    if len(regional_forms) != 12:
        errors.append(f"Korean regional-form count={len(regional_forms)}")
    if len(custom_megas) != 5:
        errors.append(f"custom Mega count={len(custom_megas)}")
    if pending_custom:
        errors.append(f"pending custom sprites={len(pending_custom)}")
    for entry in data["entries"]:
        for pose in ("front", "back"):
            path = CATALOG / entry["slug"] / f"{pose}.png"
            if not path.is_file() or path.stat().st_size == 0:
                errors.append(str(path.relative_to(ROOT)))
    for entry in data["custom_entries"]:
        for pose, relative in entry["sprites"].items():
            path = REGISTRY.parent / relative
            if not path.is_file() or path.stat().st_size == 0:
                errors.append(f"custom:{entry['slug']}/{pose}")
    print(f"SPRITE_CATALOG canonical={len(canonical)} mega={len(megas)} starters={len(custom_starters)} guardians={len(guardians)} regional={len(regional_forms)} custom_mega={len(custom_megas)} pending={len(pending_custom)} errors={len(errors)}")
    for item in errors[:30]:
        print(f"ERROR {item}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
