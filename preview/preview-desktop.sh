#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=preview/lib.sh
source "$ROOT/preview/lib.sh"

CHROOT="$ROOT/chroot"
DISPLAY_NUM="${DISPLAY_NUM:-1}"
RES="${PREVIEW_RES:-1600x900}"

if [ ! -d "$CHROOT" ] || [ ! -f "$CHROOT/usr/bin/startxfce4" ] 2>/dev/null; then
  echo "Chroot de live-build no encontrado en $CHROOT" >&2
  echo "" >&2
  echo "Opciones:" >&2
  echo "  1) Nivel 0 (instantáneo):  ./preview/preview-html.sh" >&2
  echo "  2) Build chroot en Docker:" >&2
  echo "       docker run --rm --privileged -v \"$ROOT:/build\" -w /build metta-os-builder \\" >&2
  echo "         -c 'lb config -a amd64 -- --variant xfce-light && lb build_nochroot'" >&2
  echo "  3) Build ISO completo:       METTA_VARIANT=xfce-light ./scripts/ci-build.sh" >&2
  echo "" >&2
  echo "Abriendo mockup HTML como fallback..." >&2
  preview_open "file://$ROOT/preview/mockup.html"
  exit 0
fi

if ! command -v Xephyr >/dev/null 2>&1; then
  echo "Instala Xephyr:" >&2
  echo "  Arch:   sudo pacman -S xorg-server-xephyr" >&2
  echo "  Debian: sudo apt install xserver-xephyr" >&2
  exit 1
fi

if ! command -v systemd-nspawn >/dev/null 2>&1; then
  echo "Instala systemd-nspawn (Arch: pacman -S systemd)" >&2
  exit 1
fi

Xephyr ":$DISPLAY_NUM" -screen "$RES" -ac &
XEPHYR_PID=$!
sleep 2

cleanup() {
  kill "$XEPHYR_PID" 2>/dev/null || true
}
trap cleanup EXIT

sudo systemd-nspawn -D "$CHROOT" \
  --bind=/tmp/.X11-unix \
  --setenv=DISPLAY=":$DISPLAY_NUM" \
  /bin/bash -lc 'startxfce4' &

echo "Escritorio Xfce en Xephyr :$DISPLAY_NUM ($RES)"
wait
