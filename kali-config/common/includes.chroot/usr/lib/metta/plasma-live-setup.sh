#!/bin/sh
# Apply METTA OS wallpaper, look-and-feel and theme on Plasma session start.

WALLPAPER="/usr/share/backgrounds/metta/metta-matrix-with-logo.png"
[ -f "$WALLPAPER" ] || WALLPAPER="/usr/share/backgrounds/metta/metta-matrix-default.png"
[ -f "$WALLPAPER" ] || exit 0

wait=0
while [ "$wait" -lt 30 ]; do
  if command -v qdbus6 >/dev/null 2>&1 && qdbus6 org.kde.plasmashell >/dev/null 2>&1; then
    break
  fi
  if command -v qdbus >/dev/null 2>&1 && qdbus org.kde.plasmashell >/dev/null 2>&1; then
    break
  fi
  sleep 1
  wait=$((wait + 1))
done

if command -v lookandfeeltool >/dev/null 2>&1; then
  lookandfeeltool -a org.mettaos.desktop 2>/dev/null || true
fi

if command -v plasma-apply-colors >/dev/null 2>&1; then
  plasma-apply-colors Metta-Dark 2>/dev/null || true
fi

if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
  plasma-apply-wallpaperimage "$WALLPAPER" 2>/dev/null || true
fi

if command -v kwriteconfig6 >/dev/null 2>&1; then
  kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus-Dark 2>/dev/null || true
  kwriteconfig6 --file kdeglobals --group General --key ColorScheme Metta-Dark 2>/dev/null || true
elif command -v kwriteconfig5 >/dev/null 2>&1; then
  kwriteconfig5 --file kdeglobals --group Icons --key Theme Papirus-Dark 2>/dev/null || true
  kwriteconfig5 --file kdeglobals --group General --key ColorScheme Metta-Dark 2>/dev/null || true
fi

exit 0
