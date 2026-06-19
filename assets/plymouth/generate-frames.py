"""Generate Plymouth animation frames for METTA OS boot."""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

W, H = 800, 600
FRAMES = 30


def find_logo(root: Path) -> Path:
    for candidate in (
        root / "assets/source/metta-logo-source.png",
        root / "kali-config/common/includes.chroot/usr/share/pixmaps/metta-greeter-logo.png",
        root / "kali-config/common/includes.chroot/usr/share/plymouth/themes/metta/logo.png",
    ):
        if candidate.is_file():
            return candidate
    raise SystemExit("Logo source not found for Plymouth frames")


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    out = Path(sys.argv[1] if len(sys.argv) > 1 else root / "kali-config/common/includes.chroot/usr/share/plymouth/themes/metta")
    out.mkdir(parents=True, exist_ok=True)

    logo = Image.open(find_logo(root)).convert("RGBA").resize((200, 200), Image.Resampling.LANCZOS)

    for i in range(FRAMES + 1):
        frame = Image.new("RGBA", (W, H), (10, 14, 12, 255))
        alpha = i / FRAMES
        logo_copy = logo.copy()
        r, g, b, a = logo_copy.split()
        a_arr = (np.array(a, dtype=np.float32) * alpha).astype(np.uint8)
        logo_copy.putalpha(Image.fromarray(a_arr))
        frame.paste(logo_copy, (W // 2 - 100, H // 2 - 120), logo_copy)

        draw = ImageDraw.Draw(frame)
        bar_w = int(300 * alpha)
        draw.rounded_rectangle([(W // 2 - 150, H // 2 + 110), (W // 2 + 150, H // 2 + 118)], radius=4, fill=(26, 36, 32, 255))
        if bar_w > 0:
            draw.rounded_rectangle([(W // 2 - 150, H // 2 + 110), (W // 2 - 150 + bar_w, H // 2 + 118)], radius=4, fill=(43, 227, 131, 255))

        frame.convert("RGB").save(out / f"logo_frame_{i:03d}.png")

    progress = Image.new("RGB", (300, 8), (43, 227, 131))
    progress.save(out / "progress_bar.png")
    print(f"Generated {FRAMES + 1} frames → {out}")


if __name__ == "__main__":
    main()
