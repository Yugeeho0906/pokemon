#!/usr/bin/env python3
"""Split approved guardian battle-pose pairs into Godot-ready front/back PNGs."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/generated/battle"
GUARDIANS = ("cheonhwagu", "cheonhwarin", "wolhwarok", "cheonghaeryong", "geumnyeonhwa", "wolhaeryeong")
TARGET = 192
SAFE_MARGIN = 20


def fit_to_canvas(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Pose image has no visible alpha pixels")
    cropped = rgba.crop(bbox)
    max_side = TARGET - SAFE_MARGIN * 2
    scale = min(max_side / max(cropped.width, cropped.height), 1.0)
    size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    cropped = cropped.resize(size, Image.Resampling.NEAREST)
    output = Image.new("RGBA", (TARGET, TARGET), (0, 0, 0, 0))
    output.alpha_composite(cropped, ((TARGET - size[0]) // 2, (TARGET - size[1]) // 2))
    return output


def main() -> None:
    for guardian in GUARDIANS:
        pair = Image.open(ASSETS / f"{guardian}_pair.png").convert("RGBA")
        middle = pair.width // 2
        poses = {"front": pair.crop((0, 0, middle, pair.height)), "back": pair.crop((middle, 0, pair.width, pair.height))}
        for pose, image in poses.items():
            fit_to_canvas(image).save(ASSETS / f"{guardian}_{pose}.png", optimize=True)
        print(f"Prepared {guardian} front/back")


if __name__ == "__main__":
    main()
