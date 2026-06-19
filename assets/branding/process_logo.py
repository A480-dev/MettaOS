#!/usr/bin/env python3
"""Extract METTA OS logo from source PNG and generate branding assets."""

from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/source/metta-logo-source.png"
SVG_DIR = ROOT / "assets/branding/svg"
OUT_BRANDING = ROOT / "assets/branding/generated"
INCLUDES_BRANDING = ROOT / "kali-config/common/includes.chroot/usr/share/metta/branding"
WALLPAPER_DIR = ROOT / "kali-config/common/includes.chroot/usr/share/backgrounds/metta"
ICONS_DIR = ROOT / "kali-config/common/includes.chroot/usr/share/icons/metta"

GREEN = (43, 227, 131, 255)
ICON_SIZES = (16, 32, 48, 64, 128, 256, 512)


def fg_mask(arr: np.ndarray, strict: bool = False) -> np.ndarray:
    r, g, b = arr[:, :, 0].astype(int), arr[:, :, 1].astype(int), arr[:, :, 2].astype(int)
    lo, rg, bg = (90, 15, 5) if not strict else (110, 25, 15)
    base = (g > lo) & (g > r + rg) & (g > b + bg)
    h, w = base.shape
    dense = np.zeros_like(base)
    for y in range(h):
        for x in range(w):
            if not base[y, x]:
                continue
            y0, y1 = max(0, y - 2), min(h, y + 3)
            x0, x1 = max(0, x - 2), min(w, x + 3)
            if base[y0:y1, x0:x1].sum() >= 6:
                dense[y, x] = True
    return dense


def rgba_from_source(crop: tuple[int, int, int, int], strict: bool = False) -> Image.Image:
    src = Image.open(SOURCE).convert("RGBA")
    region = src.crop(crop)
    arr = np.array(region)
    mask = fg_mask(arr, strict=strict)
    out = np.zeros_like(arr)
    out[mask] = arr[mask]
    out[~mask, 3] = 0
    return Image.fromarray(out, "RGBA")


def trim(im: Image.Image) -> Image.Image:
    bg = Image.new("RGBA", im.size, (0, 0, 0, 0))
    bbox = ImageChops.difference(im, bg).getbbox()
    return im.crop(bbox) if bbox else im


def fit_canvas(im: Image.Image, size: int, pad: float = 0.08) -> Image.Image:
    im = trim(im)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = int(size * (1 - 2 * pad))
    im.thumbnail((inner, inner), Image.Resampling.LANCZOS)
    ox = (size - im.width) // 2
    oy = (size - im.height) // 2
    canvas.paste(im, (ox, oy), im)
    return canvas


def fit_horizontal(im: Image.Image, width: int, height: int) -> Image.Image:
    im = trim(im)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    im.thumbnail((width, height), Image.Resampling.LANCZOS)
    ox = (width - im.width) // 2
    oy = (height - im.height) // 2
    canvas.paste(im, (ox, oy), im)
    return canvas


def stack_full(icon: Image.Image, wordmark: Image.Image, width: int = 2048) -> Image.Image:
    icon = trim(icon)
    wordmark = trim(wordmark)
    gap = int(width * 0.04)
    iw = int(width * 0.55)
    icon = icon.copy()
    icon.thumbnail((iw, iw), Image.Resampling.LANCZOS)
    ww = int(width * 0.88)
    wordmark = wordmark.copy()
    wordmark.thumbnail((ww, int(width * 0.12)), Image.Resampling.LANCZOS)
    height = icon.height + gap + wordmark.height + int(width * 0.06)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.paste(icon, ((width - icon.width) // 2, 0), icon)
    canvas.paste(wordmark, ((width - wordmark.width) // 2, icon.height + gap), wordmark)
    return canvas


def flat_icon(size: int, color: tuple[int, int, int, int]) -> Image.Image:
    svg = SVG_DIR / ("metta-icon-white.svg" if color[0] == 255 else "metta-icon-mono.svg")
    try:
        import cairosvg  # optional
        import io

        png = cairosvg.svg2png(url=str(svg), output_width=size, output_height=size)
        return Image.open(io.BytesIO(png)).convert("RGBA")
    except Exception:
        im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(im)
        c = color[:3]
        cx, cy, r = size // 2, size // 2, int(size * 0.42)
        draw.arc([cx - r, cy - r, cx + r, cy + r], 200, 340, fill=c, width=max(2, size // 24))
        draw.arc([cx - r, cy - r, cx + r, cy + r], 20, 160, fill=c, width=max(2, size // 24))
        m = int(size * 0.28)
        draw.polygon(
            [(cx - m, cy + m), (cx - m, cy - m), (cx - m // 3, cy - m // 3),
             (cx, cy + m // 6), (cx + m // 3, cy - m // 3), (cx + m, cy - m),
             (cx + m, cy + m), (cx + m // 3, cy), (cx, cy + m // 2),
             (cx - m // 3, cy), (cx - m, cy + m)],
            fill=c,
        )
        return im


def render_svg_png(svg_path: Path, out: Path, width: int, height: int | None = None) -> bool:
    height = height or width
    if shutil.which("rsvg-convert"):
        import subprocess

        subprocess.run(
            ["rsvg-convert", "-w", str(width), "-h", str(height), str(svg_path), "-o", str(out)],
            check=True,
        )
        return True
    return False


def composite_wallpaper(logo_full: Image.Image, wallpaper: Path, out: Path) -> None:
    if not wallpaper.exists():
        return
    bg = Image.open(wallpaper).convert("RGBA")
    logo = logo_full.copy()
    logo.thumbnail((int(bg.width * 0.35), int(bg.height * 0.35)), Image.Resampling.LANCZOS)
    x = (bg.width - logo.width) // 2
    y = int(bg.height * 0.28)
    bg.paste(logo, (x, y), logo)
    bg.convert("RGB").save(out, "PNG", optimize=True)


def write_neofetch_ascii() -> None:
    art = """
       ███╗   ███╗███████╗████████╗████████╗ █████╗ 
       ████╗ ████║██╔════╝╚══██╔══╝╚══██╔══╝██╔══██╗
       ██╔████╔██║█████╗     ██║      ██║   ███████║
       ██║╚██╔╝██║██╔══╝     ██║      ██║   ██╔══██║
       ██║ ╚═╝ ██║███████╗   ██║      ██║   ██║  ██║
       ╚═╝     ╚═╝╚══════╝   ╚═╝      ╚═╝   ╚═╝  ╚═╝
              METTA OS — Matrix Edition
"""
    targets = [
        ROOT / "kali-config/common/includes.chroot/etc/skel/.config/neofetch/metta.txt",
        ROOT / "kali-config/common/includes.chroot/etc/skel/.config/neofetch/config.conf",
    ]
    (ROOT / "kali-config/common/includes.chroot/etc/skel/.config/neofetch").mkdir(parents=True, exist_ok=True)
    targets[0].write_text(art.strip() + "\n", encoding="utf-8")


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Missing source logo: {SOURCE}")

    w, h = Image.open(SOURCE).size
    icon_crop = (int(w * 0.08), int(h * 0.06), int(w * 0.92), int(h * 0.62))
    word_crop = (int(w * 0.05), int(h * 0.68), int(w * 0.95), int(h * 0.96))
    full_crop = (int(w * 0.05), int(h * 0.04), int(w * 0.95), int(h * 0.97))

    icon_rgba = rgba_from_source(icon_crop, strict=True)
    word_rgba = rgba_from_source(word_crop, strict=False)
    full_rgba = rgba_from_source(full_crop, strict=False)

    dirs = {
        "svg": OUT_BRANDING / "svg",
        "png/icon": OUT_BRANDING / "png/icon",
        "png/full": OUT_BRANDING / "png/full",
        "mono": OUT_BRANDING / "mono",
    }
    for d in dirs.values():
        d.mkdir(parents=True, exist_ok=True)
    for name in ("metta-icon.svg", "metta-icon-mono.svg", "metta-icon-white.svg", "metta-wordmark.svg"):
        shutil.copy2(SVG_DIR / name, dirs["svg"] / name)

    icon_rgba.save(dirs["png/icon"] / "metta-icon-source-extract.png")
    word_rgba.save(dirs["png/full"] / "metta-wordmark-extract.png")
    full_rgba.save(dirs["png/full"] / "metta-full-extract.png")

    full_composed = stack_full(icon_rgba, word_rgba, 2048)
    full_composed.save(dirs["png/full"] / "metta-full-2048.png")

    icon_tex_512 = fit_canvas(icon_rgba, 512)
    icon_tex_512.save(dirs["png/icon"] / "metta-icon-512-textured.png")

    for size in ICON_SIZES:
        if size <= 48:
            im = flat_icon(size, GREEN)
        else:
            im = fit_canvas(icon_rgba, size)
        im.save(dirs["png/icon"] / f"metta-icon-{size}.png")

    for size in ICON_SIZES:
        flat_icon(size, GREEN).save(dirs["mono"] / f"metta-icon-mono-{size}.png")
        flat_icon(size, (255, 255, 255, 255)).save(dirs["mono"] / f"metta-icon-white-{size}.png")

    full_composed.save(dirs["png/full"] / "metta-full-2048.png")

    deploy = INCLUDES_BRANDING
    for sub in ("svg", "png/icon", "png/full", "mono"):
        dst = deploy / sub
        dst.mkdir(parents=True, exist_ok=True)
        for f in (OUT_BRANDING / sub).glob("*"):
            shutil.copy2(f, dst / f.name)

    shutil.copy2(dirs["svg"] / "metta-icon.svg", deploy / "metta-logo.svg")

    wp = WALLPAPER_DIR / "metta-matrix-default.png"
    alt_wp = ROOT / "assets/wallpaper/metta-matrix-default.png"
    if wp.exists() or alt_wp.exists():
        composite_wallpaper(
            full_composed,
            wp if wp.exists() else alt_wp,
            WALLPAPER_DIR / "metta-matrix-with-logo.png",
        )

    grub_dirs = [
        ROOT / "kali-config/common/includes.chroot/boot/grub/themes/metta",
        ROOT / "kali-config/common/bootloaders/grub-pc/theme",
    ]
    splash_icon = fit_canvas(icon_rgba, 256)
    for gd in grub_dirs:
        gd.mkdir(parents=True, exist_ok=True)
        splash_icon.save(gd / "icon.png")
        mono = flat_icon(256, GREEN)
        mono.save(gd / "icon-mono.png")

    plymouth = ROOT / "kali-config/common/includes.chroot/usr/share/plymouth/themes/metta"
    plymouth.mkdir(parents=True, exist_ok=True)
    fit_canvas(icon_rgba, 512).save(plymouth / "logo.png")
    flat_icon(512, GREEN).save(plymouth / "logo-mono.png")

    lightdm = ROOT / "kali-config/common/includes.chroot/usr/share/pixmaps"
    lightdm.mkdir(parents=True, exist_ok=True)
    full_composed.convert("RGB").save(lightdm / "metta-greeter-logo.png")

    for size in (16, 32, 48, 64, 128, 256):
        icodir = ICONS_DIR / f"{size}x{size}/apps"
        icodir.mkdir(parents=True, exist_ok=True)
        src = dirs["mono"] / f"metta-icon-mono-{size}.png" if size <= 32 else dirs["png/icon"] / f"metta-icon-{size}.png"
        if src.exists():
            shutil.copy2(src, icodir / "mettaos.png")

    write_neofetch_ascii()
    print(f"Logo assets written to {deploy}")


if __name__ == "__main__":
    main()
