#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BRANDING_SRC="$ROOT/assets/branding"
WALLPAPER_SRC="$ROOT/assets/wallpaper"
BRANDING_DST="$ROOT/kali-config/common/includes.chroot/usr/share/metta/branding"
WALLPAPER_DST="$ROOT/kali-config/common/includes.chroot/usr/share/backgrounds/metta"
GRUB_THEME="$ROOT/kali-config/common/bootloaders/grub-pc"

mkdir -p "$BRANDING_DST" "$WALLPAPER_DST" "$GRUB_THEME/theme"

cp "$BRANDING_SRC/metta-logo.svg" "$BRANDING_DST/"

if command -v rsvg-convert >/dev/null 2>&1; then
  for size in 16 32 48 64 128 256; do
    rsvg-convert -w "$size" -h "$size" \
      "$BRANDING_SRC/metta-logo.svg" \
      -o "$BRANDING_DST/metta-logo-${size}.png"
  done
  rsvg-convert -w 1920 -h 1080 "$BRANDING_SRC/metta-logo.svg" \
    -o "$BRANDING_DST/metta-logo-splash.png"
  rsvg-convert -w 1920 -h 1080 -b black "$BRANDING_SRC/metta-logo.svg" \
    -o "$GRUB_THEME/splash.png" 2>/dev/null || \
    rsvg-convert -w 1920 -h 1080 "$BRANDING_SRC/metta-logo.svg" \
      -o "$GRUB_THEME/splash.png"
  rsvg-convert -w 256 -h 256 -f png -o "$BRANDING_DST/metta-logo-mono.png" \
    --background-color=white "$BRANDING_SRC/metta-logo.svg" 2>/dev/null || \
    convert -background black -fill white "$BRANDING_SRC/metta-logo.svg" \
      -resize 256x256 "$BRANDING_DST/metta-logo-mono.png" 2>/dev/null || true
elif command -v convert >/dev/null 2>&1; then
  for size in 16 32 48 64 128 256; do
    convert -background none -resize "${size}x${size}" \
      "$BRANDING_SRC/metta-logo.svg" "$BRANDING_DST/metta-logo-${size}.png"
  done
  convert -background '#0D0F0D' -resize 1920x1080 \
    "$BRANDING_SRC/metta-logo.svg" "$BRANDING_DST/metta-logo-splash.png"
  cp "$BRANDING_DST/metta-logo-splash.png" "$GRUB_THEME/splash.png"
else
  echo "WARN: install rsvg-convert or imagemagick to generate PNG assets" >&2
fi

python3 "$WALLPAPER_SRC/generate_matrix_wallpaper.py"
cp "$WALLPAPER_SRC/metta-matrix-default.png" "$WALLPAPER_DST/"

# Installed-system GRUB theme assets
GRUB_INSTALLED="$ROOT/kali-config/common/includes.chroot/boot/grub/themes/metta"
mkdir -p "$GRUB_INSTALLED"
if [ -f "$GRUB_THEME/splash.png" ]; then
  cp "$GRUB_THEME/splash.png" "$GRUB_INSTALLED/background.png"
  cp "$GRUB_THEME/splash.png" "$GRUB_INSTALLED/splash.png"
fi
cp "$ROOT/kali-config/common/bootloaders/grub-pc/theme/theme.txt" "$GRUB_INSTALLED/theme.txt" 2>/dev/null || true
if [ -d "$GRUB_THEME/theme" ]; then
  cp "$GRUB_THEME/theme"/select_*.png "$GRUB_INSTALLED/" 2>/dev/null || true
fi

# GRUB selection highlight placeholders (solid green bars)
if command -v convert >/dev/null 2>&1; then
  convert -size 800x36 xc:'#00FF41' "$GRUB_THEME/theme/select_c.png"
  convert -size 800x36 xc:'#00FFFF' "$GRUB_THEME/theme/select_e.png"
  convert -size 800x36 xc:'#FFFFFF' "$GRUB_THEME/theme/select_w.png"
  convert -size 800x36 xc:'#00FF41' "$GRUB_THEME/theme/select_s.png"
  convert -size 800x36 xc:'#00FF41' "$GRUB_THEME/theme/select_n.png"
  convert -size 800x36 xc:'#00FF41' "$GRUB_THEME/theme/select_sw.png"
  convert -size 800x36 xc:'#00FF41' "$GRUB_THEME/theme/select_se.png"
  convert -size 800x36 xc:'#00FF41' "$GRUB_THEME/theme/select_nw.png"
  convert -size 800x36 xc:'#00FF41' "$GRUB_THEME/theme/select_ne.png"
fi

ISOLINUX="$ROOT/kali-config/common/includes.binary/isolinux"
mkdir -p "$ISOLINUX"
if [ -f "$GRUB_THEME/splash.png" ]; then
  cp "$GRUB_THEME/splash.png" "$ISOLINUX/splash.png"
fi

DISK_INFO="$ROOT/kali-config/common/includes.binary/.disk"
mkdir -p "$DISK_INFO"
echo 'METTA OS 1.0 "Matrix" - Live amd64' > "$DISK_INFO/info"

echo "Assets generated into includes.chroot, bootloaders, and includes.binary."
