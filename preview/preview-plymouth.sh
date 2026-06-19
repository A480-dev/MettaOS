#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=preview/lib.sh
source "$ROOT/preview/lib.sh"

THEME_SRC="$ROOT/kali-config/common/includes.chroot/usr/share/plymouth/themes/metta"
THEME_DST="/usr/share/plymouth/themes/metta"

if [ ! -f "$THEME_SRC/logo.png" ]; then
  "$ROOT/scripts/generate-assets.sh"
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "Plymouth requiere root. Ejecuta:" >&2
  echo "  sudo $0" >&2
  echo "" >&2
  echo "Fallback (sin root): mockup HTML" >&2
  preview_open "file://$ROOT/preview/mockup.html"
  exit 0
fi

if ! command -v plymouth >/dev/null 2>&1; then
  echo "Plymouth no instalado." >&2
  echo "  Arch:   sudo pacman -S plymouth" >&2
  echo "  Debian: sudo apt install plymouth" >&2
  echo "" >&2
  echo "Fallback: logo Plymouth en $THEME_SRC/logo.png" >&2
  preview_open "$THEME_SRC/logo.png"
  exit 0
fi

mkdir -p "$(dirname "$THEME_DST")"
rm -rf "$THEME_DST"
cp -r "$THEME_SRC" "$THEME_DST"

plymouth-set-default-theme metta
plymouthd --debug --tty=/dev/tty7
plymouth --show-splash
sleep 6
plymouth --quit
echo "Preview Plymouth finalizado."
