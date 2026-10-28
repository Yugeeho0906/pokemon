#!/usr/bin/env python3
"""Split generated transparent battle-pose pairs into consistent Godot sprite PNGs."""
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
BATTLE = ROOT / "assets" / "generated" / "battle"
SPECIES = [
    "ralts", "purunae", "hwarangi", "padoring", "pidgey", "caterpie",
    "pidgeotto", "pidgeot", "purusori", "ulchangryeong", "bulhoryeong",
    "jinhwarang", "mulgyeoldari", "haeryushin", "kirlia", "gardevoir",
    "metapod", "butterfree",
]
TARGET = 192


def normalized_half(image: Image.Image, half: int) -> Image.Image:
    width, height = image.size
    left = 0 if half == 0 else width // 2
    right = width // 2 if half == 0 else width
    crop = image.crop((left, 0, right, height)).convert("RGBA")
    alpha = crop.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value > 10 else 0).getbbox()
    if bbox is None:
        raise ValueError("transparent half contains no sprite")
    sprite = crop.crop(bbox)
    sprite.thumbnail((TARGET - 22, TARGET - 22), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (TARGET, TARGET), (0, 0, 0, 0))
    x = (TARGET - sprite.width) // 2
    y = TARGET - sprite.height - 8
    canvas.alpha_composite(sprite, (x, y))
    return canvas


def main() -> None:
    missing = []
    prepared = []
    for species in SPECIES:
        pair = BATTLE / f"{species}_pair.png"
        if not pair.exists():
            missing.append(species)
            continue
        image = Image.open(pair).convert("RGBA")
        normalized_half(image, 0).save(BATTLE / f"{species}_front.png", optimize=True)
        normalized_half(image, 1).save(BATTLE / f"{species}_back.png", optimize=True)
        prepared.append(species)
    print("prepared:", ", ".join(prepared) if prepared else "none")
    if missing:
        print("missing:", ", ".join(missing))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
