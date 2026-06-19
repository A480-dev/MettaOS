#!/usr/bin/env python3
"""Generate METTA OS Matrix rain wallpaper (3840x2160)."""

import random
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError as exc:
    sys.exit(
        "ERROR: python3-pillow required (apt install python3-pillow)\n"
        "  or run generate-assets.sh inside the Docker builder."
    )

WIDTH = 3840
HEIGHT = 2160
COLUMNS = 120
BG = (10, 14, 12)
GREEN = (43, 227, 131)


def main() -> None:
    out = Path(__file__).resolve().parent / "metta-matrix-default.png"
    img = Image.new("RGB", (WIDTH, HEIGHT), BG)
    draw = ImageDraw.Draw(img)

    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 18)
    except OSError:
        font = ImageFont.load_default()

    col_w = WIDTH // COLUMNS
    for col in range(COLUMNS):
        x = col * col_w + col_w // 4
        length = random.randint(8, 40)
        start = random.randint(-length * 20, HEIGHT // 2)
        for row in range(length):
            y = start + row * 22
            if y < 0 or y > HEIGHT:
                continue
            brightness = max(30, 255 - row * 6)
            color = (
                int(GREEN[0] * brightness / 255),
                int(GREEN[1] * brightness / 255),
                int(GREEN[2] * brightness / 255),
            )
            char = random.choice("01")
            draw.text((x, y), char, fill=color, font=font)

    img.save(out, "PNG", optimize=True)
    print(f"Wrote {out} ({out.stat().st_size // 1024} KiB)")


if __name__ == "__main__":
    main()
