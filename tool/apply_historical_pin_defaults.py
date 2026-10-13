"""Convert reviewed English-map pixels into bundled Arabic-map pin coordinates.

Run after editing historical_pin_evidence.csv:
    python tool/apply_historical_pin_defaults.py

The app stores normalized Arabic-image coordinates. Its existing alignment grid
places them on the English scan. This script inverts that same grid, so the two
map views share one pin location rather than separate hand-entered positions.
"""

import csv
import json
import math
import re
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "tool" / "historical_pin_evidence.csv"
CITIES = ROOT / "assets" / "data" / "cities.json"
ENGLISH_IMAGE = ROOT / "assets" / "maps" / "idrisi_map_en.jpg"
ALIGNMENT = ROOT / "lib" / "utils" / "map_alignment_data.dart"


def load_alignment() -> tuple[int, int, list[float]]:
    source = ALIGNMENT.read_text(encoding="utf-8")
    columns = int(re.search(r"mapAlignmentColumns = (\d+)", source).group(1))
    rows = int(re.search(r"mapAlignmentRows = (\d+)", source).group(1))
    values = re.search(r"mapAlignmentEnglishNodes = \[(.*?)\];", source, re.S).group(1)
    nodes = [float(value) for value in re.findall(r"-?\d+\.\d+", values)]
    if len(nodes) != columns * rows * 2:
        raise ValueError("Alignment grid size does not match its dimensions")
    return columns, rows, nodes


def main() -> None:
    columns, rows, nodes = load_alignment()

    def to_english(x: float, y: float) -> tuple[float, float]:
        grid_x, grid_y = x * (columns - 1), y * (rows - 1)
        column = max(0, min(columns - 2, math.floor(grid_x)))
        row = max(0, min(rows - 2, math.floor(grid_y)))
        fx, fy = grid_x - column, grid_y - row

        def interpolate(axis: int) -> float:
            top_left = 2 * (row * columns + column) + axis
            top_right = top_left + 2
            bottom_left = top_left + 2 * columns
            bottom_right = bottom_left + 2
            top = nodes[top_left] * (1 - fx) + nodes[top_right] * fx
            bottom = nodes[bottom_left] * (1 - fx) + nodes[bottom_right] * fx
            return top * (1 - fy) + bottom * fy

        return interpolate(0), interpolate(1)

    def from_english(x: float, y: float) -> tuple[float, float]:
        ax, ay = x, y
        step = 0.00001
        for _ in range(10):
            mx, my = to_english(ax, ay)
            error_x, error_y = mx - x, my - y
            if max(abs(error_x), abs(error_y)) < 1e-12:
                break
            xx, xy = to_english(ax + step, ay)
            yx, yy = to_english(ax, ay + step)
            a, b = (xx - mx) / step, (yx - mx) / step
            c, d = (xy - my) / step, (yy - my) / step
            determinant = a * d - b * c
            if abs(determinant) < 1e-8:
                raise ValueError("Alignment grid is singular near this pin")
            ax -= (d * error_x - b * error_y) / determinant
            ay -= (-c * error_x + a * error_y) / determinant
        return ax, ay

    with Image.open(ENGLISH_IMAGE) as image:
        width, height = image.size
    with EVIDENCE.open(encoding="utf-8", newline="") as file:
        evidence = list(csv.DictReader(file))
    cities = json.loads(CITIES.read_text(encoding="utf-8"))
    by_id = {row["id"]: row for row in evidence}
    if len(cities) != len(evidence) or len(by_id) != len(evidence):
        raise ValueError("Expected one unique evidence row per catalog record")
    if set(by_id) != {city["id"] for city in cities}:
        raise ValueError("Evidence IDs do not match bundled city IDs")

    for city in cities:
        row = by_id[city["id"]]
        pixel_x, pixel_y = float(row["english_x"]), float(row["english_y"])
        if not (0 <= pixel_x <= width and 0 <= pixel_y <= height):
            raise ValueError(f"{city['id']}: English pixel is outside the scan")
        arabic_x, arabic_y = from_english(pixel_x / width, pixel_y / height)
        projected_x, projected_y = to_english(arabic_x, arabic_y)
        error = math.hypot(
            (projected_x * width - pixel_x), (projected_y * height - pixel_y)
        )
        if not (0 <= arabic_x <= 1 and 0 <= arabic_y <= 1) or error > 1:
            raise ValueError(f"{city['id']}: maps do not align ({error:.1f}px)")
        city["px"], city["py"] = round(arabic_x, 7), round(arabic_y, 7)
        city["pinBasis"] = row["basis"]
        city["pinNote"] = row["review_note"]

    CITIES.write_text(json.dumps(cities, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    counts = {basis: sum(row["basis"] == basis for row in evidence) for basis in ("label", "region", "estimated")}
    print(f"Updated {len(cities)} bundled pins: {counts}")


if __name__ == "__main__":
    main()
