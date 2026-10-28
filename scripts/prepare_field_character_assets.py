#!/usr/bin/env python3
"""Normalize generated character atlases into 4x3 Godot field spritesheets.

Input contract: transparent PNG with 4 columns (down, left, right, up) and
3 rows (idle, walk A, walk B). Input artwork is preserved unchanged.
"""
from __future__ import annotations

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART_DIR = ROOT / "assets/generated/field_characters"
CELL = 48

CHARACTERS = {
    "seol_yuna": "seol_yuna_sheet.png",
    "yun_seorin": "yun_seorin_sheet.png",
    "moon_si_yeon": "moon_si_yeon_sheet.png",
    "hae_nari": "hae_nari_sheet.png",
    "erika": "erika_sheet.png",
    "reina": "reina_sheet.png",
    "kaien": "kaien_sheet.png",
    "shiori": "shiori_sheet.png",
    "se_arin": "se_arin_concept_sheet.png",
    "ren_kaito": "ren_kaito_concept_sheet.png",
    "karen_yuzuhwa": "karen_yuzuhwa_concept_sheet.png",
    "shin_tsukasa": "shin_tsukasa_concept_sheet.png",
}


def normalize(character_id: str, filename: str) -> None:
    source_path = ART_DIR / filename
    if not source_path.exists():
        print(f"WAIT {character_id}: {filename} not generated yet")
        return
    source = Image.open(source_path).convert("RGBA")
    alpha_extrema = source.getchannel("A").getextrema()
    if alpha_extrema[0] == 255:
        raise ValueError(f"{filename} has no transparent pixels; reject fake matte/checkerboard backgrounds")
    if source.width < 4 or source.height < 3:
        raise ValueError(f"Invalid atlas dimensions: {source.size}")

    atlas = Image.new("RGBA", (CELL * 4, CELL * 3), (0, 0, 0, 0))
    for row in range(3):
        y0, y1 = round(row * source.height / 3), round((row + 1) * source.height / 3)
        for col in range(4):
            x0, x1 = round(col * source.width / 4), round((col + 1) * source.width / 4)
            frame = source.crop((x0, y0, x1, y1))
            bbox = frame.getchannel("A").getbbox()
            if bbox is None:
                raise ValueError(f"Empty atlas cell in {filename}: row={row}, column={col}")
            sprite = frame.crop(bbox)
            scale = min(40 / sprite.width, 45 / sprite.height)
            resized = (max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale)))
            sprite = sprite.resize(resized, Image.Resampling.NEAREST)
            position = (col * CELL + (CELL - sprite.width) // 2, row * CELL + CELL - sprite.height - 1)
            atlas.alpha_composite(sprite, position)

    output_path = ART_DIR / f"{character_id}_walk_48.png"
    atlas.save(output_path, optimize=True)
    print(f"READY {character_id}: {output_path.relative_to(ROOT)}; input={source.size}; alpha={alpha_extrema}")


def main() -> None:
    for character_id, filename in CHARACTERS.items():
        normalize(character_id, filename)


if __name__ == "__main__":
    main()
