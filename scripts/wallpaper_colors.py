#!/usr/bin/env python3
"""Tag each wallpaper with every color that covers a meaningful share of the
image, cached by full file path. A single "dominant color" isn't enough to
answer "does this wallpaper have pink in it" - pink is very often a smaller
accent (a sunset band, a flower) that a strict top-1 color loses to whatever
covers slightly more pixels."""
import colorsys
import json
import os
import sys

from PIL import Image

EXTENSIONS = (".png", ".jpg", ".jpeg", ".webp", ".mp4", ".webm")
PALETTE_SIZE = 8
MIN_AREA_SHARE = 0.08
MAX_TAGS = 4


def thumb_path_for(thumbs_dir, wallpaper_path):
    base = os.path.splitext(os.path.basename(wallpaper_path))[0]
    return os.path.join(thumbs_dir, base + ".jpg")


def classify(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    h_deg = h * 360.0

    if v < 0.16:
        return "black"
    if s < 0.10:
        return "white" if v > 0.85 else "gray"

    # Brown is a dark, only moderately saturated orange - not just "dark red".
    # A highly saturated dark red (maroon, blood red, s > ~0.75) still reads as
    # red to a human, so it's excluded here rather than swept into brown.
    is_brownish_hue = 10 <= h_deg <= 50
    if is_brownish_hue and 0.15 <= v <= 0.55 and 0.20 <= s <= 0.75:
        return "brown"

    if h_deg < 15 or h_deg >= 345:
        return "red"
    if h_deg < 45:
        return "orange"
    if h_deg < 65:
        return "yellow"
    if h_deg < 170:
        return "green"
    if h_deg < 200:
        return "cyan"
    if h_deg < 255:
        return "blue"
    if h_deg < 290:
        return "purple"
    return "pink"


def color_tags(path):
    img = Image.open(path).convert("RGB")
    img.thumbnail((100, 100))
    total = img.width * img.height

    paletted = img.quantize(colors=PALETTE_SIZE)
    palette = paletted.getpalette()
    counts = sorted(paletted.getcolors(), reverse=True)

    tags = []
    for count, idx in counts:
        if count / total < MIN_AREA_SHARE:
            break
        bucket = classify(*palette[idx * 3:idx * 3 + 3])
        if bucket not in tags:
            tags.append(bucket)
        if len(tags) >= MAX_TAGS:
            break

    if not tags:
        tags.append(classify(*palette[counts[0][1] * 3:counts[0][1] * 3 + 3]))

    return tags


def main():
    if len(sys.argv) < 4:
        print("usage: wallpaper_colors.py <wallpapers_dir> <thumbs_dir> <cache_json>", file=sys.stderr)
        sys.exit(1)

    wallpapers_dir, thumbs_dir, cache_path = sys.argv[1:4]

    try:
        with open(cache_path) as f:
            cache = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        cache = {}

    if not os.path.isdir(wallpapers_dir):
        print(json.dumps(cache))
        return

    current_paths = set()
    for name in os.listdir(wallpapers_dir):
        if not name.lower().endswith(EXTENSIONS):
            continue
        full_path = os.path.join(wallpapers_dir, name)
        current_paths.add(full_path)
        if full_path in cache and isinstance(cache[full_path], list):
            continue

        thumb = thumb_path_for(thumbs_dir, full_path)
        if not os.path.isfile(thumb):
            continue

        try:
            cache[full_path] = color_tags(thumb)
        except Exception:
            continue

    for stale in [p for p in cache if p not in current_paths]:
        del cache[stale]

    tmp_path = cache_path + ".tmp"
    with open(tmp_path, "w") as f:
        json.dump(cache, f)
    os.replace(tmp_path, cache_path)

    print(json.dumps(cache))


if __name__ == "__main__":
    main()
