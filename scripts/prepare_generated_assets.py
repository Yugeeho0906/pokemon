#!/usr/bin/env python3
"""Prepare generated 4x3 walk sheets and a 16x16 environment atlas for Godot."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GENERATED = ROOT / "assets" / "generated"


def make_character(source_name: str, target_name: str) -> None:
    source = Image.open(GENERATED / source_name).convert("RGBA")
    width, height = source.size
    if width % 4 or height % 3:
        raise ValueError(f"{source_name} must be an exact 4 x 3 sheet")
    cell_w, cell_h = width // 4, height // 3
    frame_w, frame_h = 48, 48
    result = Image.new("RGBA", (frame_w * 4, frame_h * 3), (0, 0, 0, 0))
    resample = Image.Resampling.NEAREST
    for row in range(3):
        for col in range(4):
            frame = source.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
            alpha = frame.getchannel("A")
            # A very small cutoff removes the near-transparent fringe from generated alpha.
            mask = alpha.point(lambda value: 255 if value > 12 else 0)
            bounds = mask.getbbox()
            if bounds is None:
                continue
            sprite = frame.crop(bounds)
            sprite.thumbnail((34, 44), resample)
            x = col * frame_w + (frame_w - sprite.width) // 2
            y = row * frame_h + frame_h - sprite.height - 2
            result.alpha_composite(sprite, (x, y))
    result.save(GENERATED / target_name, optimize=True)


def main() -> None:
    atlas = Image.open(GENERATED / "incheon_tileset.png").convert("RGBA")
    if atlas.width != atlas.height or atlas.width % 16:
        raise ValueError("The generated tile atlas must be square and divisible into 16 x 16 cells")
    # 1920 / 16 = 120 px per generated cell; nearest downsampling makes 32 px atlas cells.
    atlas = atlas.resize((512, 512), Image.Resampling.NEAREST)
    atlas.save(GENERATED / "incheon_tileset_32.png", optimize=True)
    for name in ["player", "harin", "seohwa"]:
        make_character(f"{name}_walk.png", f"{name}_walk_48.png")
    print("Prepared a 512x512 32px atlas and three 4x3 48px character sheets.")


if __name__ == "__main__":
    main()
