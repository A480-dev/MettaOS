#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/imagemagick.sh
source "$ROOT/scripts/imagemagick.sh"

BRANDING_SRC="$ROOT/assets/branding"
WALLPAPER_SRC="$ROOT/assets/wallpaper"
BRANDING_DST="$ROOT/kali-config/common/includes.chroot/usr/share/metta/branding"
WALLPAPER_DST="$ROOT/kali-config/common/includes.chroot/usr/share/backgrounds/metta"
GRUB_THEME="$ROOT/kali-config/common/bootloaders/grub-pc"
PREVIEW="$ROOT/preview"

mkdir -p "$BRANDING_DST" "$WALLPAPER_DST" "$GRUB_THEME/theme" "$PREVIEW"

python3 "$WALLPAPER_SRC/generate_matrix_wallpaper.py"
cp "$WALLPAPER_SRC/metta-matrix-default.png" "$WALLPAPER_DST/"

python3 "$BRANDING_SRC/process_logo.py"

if [ -f "$WALLPAPER_DST/metta-matrix-with-logo.png" ]; then
  cp "$WALLPAPER_DST/metta-matrix-with-logo.png" "$GRUB_THEME/splash.png"
elif im_available && [ -f "$BRANDING_DST/png/full/metta-full-2048.png" ]; then
  im "$WALLPAPER_DST/metta-matrix-default.png" \
    "$BRANDING_DST/png/full/metta-full-2048.png" \
    -gravity center -composite "$GRUB_THEME/splash.png" || \
    cp "$WALLPAPER_DST/metta-matrix-default.png" "$GRUB_THEME/splash.png"
else
  cp "$WALLPAPER_DST/metta-matrix-default.png" "$GRUB_THEME/splash.png"
fi

# GRUB escala mal splash 4K en framebuffers pequeños — usar 1920x1080 nativo
if im_available && [ -f "$GRUB_THEME/splash.png" ]; then
  im "$GRUB_THEME/splash.png" \
    -resize 1920x1080^ \
    -gravity center \
    -extent 1920x1080 \
    "$GRUB_THEME/splash.png"
fi

GRUB_INSTALLED="$ROOT/kali-config/common/includes.chroot/boot/grub/themes/metta"
mkdir -p "$GRUB_INSTALLED"
cp "$GRUB_THEME/splash.png" "$GRUB_INSTALLED/background.png"
cp "$GRUB_THEME/splash.png" "$GRUB_INSTALLED/splash.png"
cp "$ROOT/kali-config/common/bootloaders/grub-pc/theme/theme.txt" "$GRUB_INSTALLED/theme.txt" 2>/dev/null || true
# Installed layout: assets live alongside theme.txt (not ../splash.png)
if [ -f "$GRUB_INSTALLED/theme.txt" ]; then
  sed -i 's|desktop-image: "../splash.png"|desktop-image: "splash.png"|' "$GRUB_INSTALLED/theme.txt"
fi

if [ -f "$BRANDING_DST/png/icon/metta-icon-256.png" ]; then
  cp "$BRANDING_DST/png/icon/metta-icon-256.png" "$GRUB_INSTALLED/icon.png"
  cp "$BRANDING_DST/mono/metta-icon-mono-256.png" "$GRUB_INSTALLED/icon-mono.png" 2>/dev/null || true
  cp "$BRANDING_DST/mono/metta-icon-mono-256.png" "$GRUB_THEME/icon-mono.png" 2>/dev/null || true
  cp "$BRANDING_DST/png/icon/metta-icon-256.png" "$GRUB_THEME/icon.png" 2>/dev/null || true
fi
if [ -d "$GRUB_THEME/theme" ]; then
  cp "$GRUB_THEME/theme"/select_*.png "$GRUB_INSTALLED/" 2>/dev/null || true
fi

if im_available; then
  for c in c e w s n sw se nw ne; do
    im -size 1200x44 "xc:#2BE383" "$GRUB_THEME/theme/select_${c}.png"
  done
fi

ISOLINUX="$ROOT/kali-config/common/includes.binary/isolinux"
mkdir -p "$ISOLINUX"
cp "$GRUB_THEME/splash.png" "$ISOLINUX/splash.png"
mkdir -p "$ROOT/kali-config/common/includes.binary/.disk"
echo 'METTA OS 1.0 "Matrix" - Live amd64' > "$ROOT/kali-config/common/includes.binary/.disk/info"

mkdir -p "$PREVIEW/assets"
for f in "$BRANDING_DST/png/icon/metta-icon-512.png" \
         "$BRANDING_DST/png/full/metta-full-2048.png" \
         "$WALLPAPER_DST/metta-matrix-default.png" \
         "$WALLPAPER_DST/metta-matrix-with-logo.png"; do
  [ -f "$f" ] && ln -sf "$f" "$PREVIEW/assets/$(basename "$f")" 2>/dev/null || true
done

echo "Assets generated (logo + wallpaper + boot splash)."
