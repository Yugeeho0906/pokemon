#!/usr/bin/env python3
"""Split approved Korean regional-form and custom-Mega pose pairs into battle sprites."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/generated/battle"
FORMS = (
    "ninetales_korean", "arcanine_korean", "bronzong_korean", "lilligant_korean",
    "noctowl_korean", "rapidash_korean", "chimecho_korean", "absol_korean",
    "lucario_korean", "falinks_korean", "decidueye_korean", "milotic_korean",
    "mega_ulchangryeong", "mega_jinhwarang", "mega_haeryushin", "mega_cheonhwagu",
    "mega_gardevoir_korean_shiny",
)
TARGET = 192
SAFE_MARGIN = 20


def fit_to_canvas(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Pose image has no visible alpha pixels")
    cropped = rgba.crop(bbox)
    side = max(cropped.width, cropped.height)
    scale = min((TARGET - SAFE_MARGIN * 2) / side, 1.0)
    size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    cropped = cropped.resize(size, Image.Resampling.NEAREST)
    output = Image.new("RGBA", (TARGET, TARGET), (0, 0, 0, 0))
    output.alpha_composite(cropped, ((TARGET - size[0]) // 2, (TARGET - size[1]) // 2))
    return output


def main() -> None:
    missing: list[str] = []
    for form in FORMS:
        path = ASSETS / f"{form}_pair.png"
        if not path.is_file():
            missing.append(form)
            continue
        pair = Image.open(path).convert("RGBA")
        center = pair.width // 2
        for pose, box in {"front": (0, 0, center, pair.height), "back": (center, 0, pair.width, pair.height)}.items():
            fit_to_canvas(pair.crop(box)).save(ASSETS / f"{form}_{pose}.png", optimize=True)
        print(f"Prepared {form} front/back")
    if missing:
        print("PENDING_PAIR " + ",".join(missing))


if __name__ == "__main__":
    main()
