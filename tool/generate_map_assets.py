"""Build small overview images and native-resolution tiles from source maps.

Requires Pillow: python -m pip install Pillow
Run from the repository root: python tool/generate_map_assets.py
The source image geometry is unchanged, so normalized pin positions still apply.
"""

from pathlib import Path
from PIL import Image


MAPS = {
    "ar": ("idrisi_map_ar.jpg", (11440, 5654)),
    "en": ("idrisi_map_en.jpg", (12999, 5958)),
}
TILE_SIZE = 1024
PREVIEW_WIDTH = 2048
MAP_DIR = Path(__file__).resolve().parents[1] / "assets" / "maps"


def build_map(language: str, source_name: str, expected_size: tuple[int, int]) -> None:
    preview_dir = MAP_DIR / "previews"
    tile_dir = MAP_DIR / "tiles" / language
    preview_dir.mkdir(parents=True, exist_ok=True)
    tile_dir.mkdir(parents=True, exist_ok=True)

    with Image.open(MAP_DIR / source_name) as source:
        if source.size != expected_size:
            raise ValueError(f"{source_name}: expected {expected_size}, got {source.size}")
        preview_height = round(source.height * PREVIEW_WIDTH / source.width)
        preview = source.resize((PREVIEW_WIDTH, preview_height), Image.Resampling.LANCZOS)
        preview.save(preview_dir / f"idrisi_map_{language}.webp", "WEBP", quality=82, method=6)

        count = 0
        for top in range(0, source.height, TILE_SIZE):
            for left in range(0, source.width, TILE_SIZE):
                tile = source.crop((left, top, min(left + TILE_SIZE, source.width),
                                    min(top + TILE_SIZE, source.height)))
                tile.save(tile_dir / f"{left // TILE_SIZE}-{top // TILE_SIZE}.webp",
                          "WEBP", quality=85, method=5)
                count += 1
    print(f"{language}: {count} tiles, preview {PREVIEW_WIDTH}x{preview_height}")


if __name__ == "__main__":
    for language, (source_name, size) in MAPS.items():
        build_map(language, source_name, size)
