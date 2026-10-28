#!/usr/bin/env python3
"""Normalize generated 3:2 pixel maps to the Godot field world's 960×640 canvas."""
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "assets" / "generated" / "maps"
TARGET = (960, 640)


def prepare(name: str) -> None:
    source = MAPS / f"{name}.png"
    if not source.exists():
        raise FileNotFoundError(source)
    image = Image.open(source).convert("RGBA")
    normalized = ImageOps.fit(image, TARGET, Image.Resampling.NEAREST, centering=(0.5, 0.5))
    normalized.save(MAPS / f"{name}_960.png", optimize=True)


def main() -> None:
    for name in ["incheon_bw_field", "route_bw_field", "suwon_bw_field", "suwon_gym_bw_field", "suwon_gym_battle_bg"]:
        prepare(name)
    print("Prepared 960×640 pixel map backgrounds.")


if __name__ == "__main__":
    main()
