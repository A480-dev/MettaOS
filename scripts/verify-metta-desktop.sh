#!/bin/bash
# Verify METTA OS desktop assets and Xfce defaults are baked into chroot or ISO.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHROOT="${1:-$ROOT/chroot}"
ISO="${2:-}"
TARGET=""
CLEANUP=()

cleanup() {
  local m
  for m in "${CLEANUP[@]}"; do
    umount "$m" 2>/dev/null || true
    rmdir "$m" 2>/dev/null || true
  done
}
trap cleanup EXIT

mount_squashfs_from_iso() {
  local iso="$1"
  local mnt sq
  mnt=$(mktemp -d)
  sq=$(mktemp -d)
  CLEANUP+=("$sq" "$mnt")
  mount -o loop,ro "$iso" "$mnt"
  mount -o loop,ro "$mnt/live/filesystem.squashfs" "$sq"
  TARGET="$sq"
}

resolve_target() {
  if [ -n "$ISO" ] && [ -f "$ISO" ]; then
    mount_squashfs_from_iso "$ISO"
  elif [ -d "$CHROOT" ]; then
    TARGET="$CHROOT"
  else
    echo "Uso: $0 [chroot_dir] [iso_file]" >&2
    exit 1
  fi
}

check_file() {
  local path="$1"
  local label="$2"
  if [ ! -f "$TARGET/$path" ]; then
    echo "FALLO: falta $label ($path)" >&2
    return 1
  fi
  return 0
}

check_grep() {
  local path="$1"
  local pattern="$2"
  local label="$3"
  if [ ! -f "$TARGET/$path" ]; then
    echo "FALLO: falta $label ($path)" >&2
    return 1
  fi
  if ! grep -qE "$pattern" "$TARGET/$path"; then
    echo "FALLO: $label no contiene patrón esperado en $path" >&2
    return 1
  fi
  return 0
}

FAILED=0

resolve_target

check_file usr/share/backgrounds/metta/metta-matrix-with-logo.png "wallpaper METTA" || FAILED=1
check_file usr/share/themes/Metta-Dark/index.theme "tema Metta-Dark" || FAILED=1
check_file usr/lib/metta/xfce-live-setup.sh "script de sesión Xfce" || FAILED=1
check_file etc/xdg/autostart/metta-xfce-setup.desktop "autostart Xfce" || FAILED=1
check_file etc/xdg/autostart/metta-xfce-setup-delayed.desktop "autostart Xfce retrasado" || FAILED=1
check_file usr/lib/metta/install-xfce-defaults.sh "instalador Xfce METTA" || FAILED=1
check_file etc/live/config.conf.d/metta.conf "config live metta" || FAILED=1

check_grep etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
  'Metta-Dark' "tema GTK en xsettings" || FAILED=1
check_grep etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml \
  'Metta-Dark' "tema xfwm4" || FAILED=1
check_grep etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml \
  'metta-matrix-with-logo\.png' "wallpaper en xfce4-desktop" || FAILED=1
check_grep etc/xdg/gtk-3.0/settings.ini \
  'Metta-Dark' "tema en gtk-3.0" || FAILED=1
check_grep etc/live/config.conf.d/metta.conf \
  'LIVE_USERNAME="metta"' "usuario live metta" || FAILED=1

if grep -q 'Kali-Dark' "$TARGET/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" 2>/dev/null; then
  echo "FALLO: xfwm4.xml aún referencia Kali-Dark" >&2
  FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi

echo "OK: escritorio METTA verificado en la imagen"
