#!/bin/sh
# Install METTA OS Plasma defaults system-wide and in /etc/skel (idempotent).

METTA_PLASMA="/usr/share/metta/plasma"
METTA_GTK="/usr/share/metta/gtk/gtk-3.0-settings.ini"
WALLPAPER="/usr/share/backgrounds/metta/metta-matrix-with-logo.png"
ETC_XDG="/etc/xdg"
SKEL_CONFIG="/etc/skel/.config"

install_file() {
  src="$1"
  dst="$2"
  [ -f "$src" ] || return 1
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
}

if [ ! -f /usr/share/color-schemes/Metta-Dark.colors ]; then
  echo "WARN: Metta-Dark color scheme missing — skipping Plasma defaults" >&2
  exit 0
fi

mkdir -p "$ETC_XDG" "$SKEL_CONFIG" "$SKEL_CONFIG/plasma"

for f in kdeglobals plasmarc kwinrc konsolerc; do
  install_file "$METTA_PLASMA/$f" "$ETC_XDG/$f" || true
  install_file "$METTA_PLASMA/$f" "$SKEL_CONFIG/$f" || true
done

install_file "$METTA_PLASMA/plasma-org.kde.plasma.desktop-appletsrc" \
  "$ETC_XDG/plasma-org.kde.plasma.desktop-appletsrc" || true
install_file "$METTA_PLASMA/plasma-org.kde.plasma.desktop-appletsrc" \
  "$SKEL_CONFIG/plasma-org.kde.plasma.desktop-appletsrc" || true

if [ -f "$METTA_GTK" ]; then
  mkdir -p /etc/xdg/gtk-3.0 "$SKEL_CONFIG/gtk-3.0"
  install_file "$METTA_GTK" /etc/xdg/gtk-3.0/settings.ini || true
  install_file "$METTA_GTK" "$SKEL_CONFIG/gtk-3.0/settings.ini" || true
fi

if [ -f "$WALLPAPER" ]; then
  for cfg in "$ETC_XDG/plasmarc" "$SKEL_CONFIG/plasmarc"; do
    [ -f "$cfg" ] || continue
    if grep -q '^\[Wallpaper\]' "$cfg" 2>/dev/null; then
      sed -i "s|^Image=.*|Image=$WALLPAPER|" "$cfg" 2>/dev/null || true
    fi
  done
fi

if [ -f /usr/lib/metta/plasma-live-setup.sh ]; then
  chmod 755 /usr/lib/metta/plasma-live-setup.sh 2>/dev/null || true
fi

exit 0
