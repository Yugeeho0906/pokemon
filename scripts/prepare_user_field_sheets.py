#!/usr/bin/env python3
"""Convert the user's 4-direction, 3-row character sheets into Godot's 48px atlas.

Grid contract: columns are down/front, left, right, up/back; rows are idle,
walk frame A, walk frame B. The source artwork is kept unchanged.
"""
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/sources/user_field_sheets"
OUTPUT = ROOT / "assets/generated"
SHEETS = {
    "player": "player_male_sheet.png",
    "seohwa": "seohwa_sheet.png",
    "harin": "harin_sheet.png",
}
CELL = 48
BG_TOLERANCE = 17


def prepare(sheet_id: str, filename: str) -> None:
    source = Image.open(SOURCE / filename).convert("RGBA")
    rgb = np.asarray(source.convert("RGB"), dtype=np.int16)
    # The supplied sheets use a uniform neutral-gray matte. Remove only pixels
    # in that background color range; keep the character's dark outlines intact.
    bg = np.array([87, 87, 86], dtype=np.int16)
    dist = np.max(np.abs(rgb - bg), axis=2)
    arr = np.asarray(source).copy()
    arr[dist <= BG_TOLERANCE, 3] = 0
    keyed = Image.fromarray(arr, "RGBA")
    atlas = Image.new("RGBA", (CELL * 4, CELL * 3), (0, 0, 0, 0))
    for row in range(3):
        y0 = round(row * source.height / 3)
        y1 = round((row + 1) * source.height / 3)
        for col in range(4):
            x0 = round(col * source.width / 4)
            x1 = round((col + 1) * source.width / 4)
            frame = keyed.crop((x0, y0, x1, y1))
            bbox = frame.getchannel("A").getbbox()
            if bbox is None:
                raise RuntimeError(f"Empty sprite: {sheet_id} row={row} col={col}")
            sprite = frame.crop(bbox)
            target_w, target_h = 40, 45
            scale = min(target_w / sprite.width, target_h / sprite.height)
            size = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
            sprite = sprite.resize(size, Image.Resampling.NEAREST)
            px = (CELL - sprite.width) // 2
            py = CELL - sprite.height - 1
            atlas.alpha_composite(sprite, (col * CELL + px, row * CELL + py))
    target = OUTPUT / f"{sheet_id}_walk_48.png"
    atlas.save(target, optimize=True)
    print(f"PREPARED {target.relative_to(ROOT)} from {filename}; source={source.size}; atlas={atlas.size}")


def main() -> None:
    for sheet_id, filename in SHEETS.items():
        prepare(sheet_id, filename)


if __name__ == "__main__":
    main()
