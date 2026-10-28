#!/usr/bin/env python3
"""Normalize the approved transparent unknown-creature front/back sprites."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = {
    "front": ROOT / "assets/generated/battle/unknown-silhouette_front_regen.png",
    "back": ROOT / "assets/generated/battle/unknown-silhouette_back_regen.png",
}
DEST = ROOT / "assets/generated/battle"
TARGET = 192


def normalize(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Sprite has no visible alpha pixels")
    cropped = rgba.crop(bbox)
    scale = min((TARGET - 22) / max(cropped.width, cropped.height), 1.0)
    size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    cropped = cropped.resize(size, Image.Resampling.NEAREST)
    out = Image.new("RGBA", (TARGET, TARGET), (0, 0, 0, 0))
    out.alpha_composite(cropped, ((TARGET - size[0]) // 2, (TARGET - size[1]) // 2))
    return out


def main() -> None:
    for pose, source in SOURCE.items():
        image = normalize(Image.open(source))
        image.save(DEST / f"unknown-silhouette_{pose}.png", optimize=True)
    print("Prepared approved unknown-silhouette front/back sprites.")


if __name__ == "__main__":
    main()
