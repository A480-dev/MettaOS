#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=preview/lib.sh
source "$ROOT/preview/lib.sh"

SRC_THEME="$ROOT/kali-config/common/includes.chroot/boot/grub/themes/metta"
PREVIEW_THEME="$ROOT/preview/grub-theme"
CFG="$ROOT/preview/grub-test.cfg"
SPLASH="$ROOT/kali-config/common/bootloaders/grub-pc/splash.png"
BOOT_ISO=0

usage() {
  cat <<EOF
Uso: $(basename "$0") [--boot-iso]

  (sin flags)     Preview del TEMA GRUB en QEMU (no arranca METTA OS)
  --boot-iso      Si hay una ISO metta-os-*.iso, arranca con test-iso.sh

Variables:
  METTA_ISO       Ruta explicita a la ISO live
  METTA_BOOT=1    Equivalente a --boot-iso

Nota: en el preview de tema, "Live system" muestra un aviso y vuelve al menu.
      Para boot real necesitas la ISO compilada.
EOF
}

find_metta_iso() {
  local candidate=""
  if [ -n "${METTA_ISO:-}" ] && [ -f "${METTA_ISO}" ]; then
    echo "${METTA_ISO}"
    return 0
  fi
  for candidate in \
    "$ROOT"/images/metta-os-*.iso \
    "$ROOT"/*.iso; do
    [ -f "$candidate" ] || continue
    case "$(basename "$candidate")" in
      kali-linux-*-installer*.iso) continue ;;
      metta-os-*.iso|*metta*live*.iso) echo "$candidate"; return 0 ;;
    esac
  done
  return 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --boot-iso) BOOT_ISO=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opcion desconocida: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [ "${METTA_BOOT:-0}" = "1" ]; then
  BOOT_ISO=1
fi

if [ "$BOOT_ISO" = "1" ]; then
  ISO="$(find_metta_iso || true)"
  if [ -z "$ISO" ]; then
    echo "No se encontro ISO METTA OS." >&2
    echo "  Compila: ./scripts/ci-build.sh" >&2
    echo "  O define: METTA_ISO=/ruta/metta-os.iso $0 --boot-iso" >&2
    exit 1
  fi
  echo "Arrancando ISO real: $ISO"
  exec "$ROOT/test-iso.sh" "$ISO"
fi

if [ ! -f "$SPLASH" ] || [ ! -f "$SRC_THEME/theme.txt" ]; then
  echo "Generando assets..." >&2
  "$ROOT/scripts/generate-assets.sh"
fi

# Directorio autocontenido para grub2-theme-preview (splash + theme.txt en la misma carpeta)
rm -rf "$PREVIEW_THEME"
mkdir -p "$PREVIEW_THEME"
cp "$SRC_THEME/theme.txt" "$PREVIEW_THEME/"
for f in splash.png background.png icon.png icon-mono.png; do
  [ -f "$SRC_THEME/$f" ] && cp "$SRC_THEME/$f" "$PREVIEW_THEME/"
done
# Glob debe evaluarse en SRC_THEME (no en cwd del usuario)
shopt -s nullglob
for f in "$SRC_THEME"/select_*.png; do
  cp "$f" "$PREVIEW_THEME/"
done
shopt -u nullglob
# Asegurar splash en carpeta del tema
[ -f "$PREVIEW_THEME/splash.png" ] || cp "$SPLASH" "$PREVIEW_THEME/splash.png"

missing_select=0
for c in c e w s n sw se nw ne; do
  [ -f "$PREVIEW_THEME/select_${c}.png" ] || missing_select=1
done
if [ "$missing_select" -ne 0 ]; then
  echo "WARN: faltan select_*.png en el tema; regenera assets." >&2
  "$ROOT/scripts/generate-assets.sh"
  for f in "$SRC_THEME"/select_*.png; do
    cp "$f" "$PREVIEW_THEME/"
  done
fi

echo ""
echo "=== Preview GRUB (solo tema) ==="
echo "Esta QEMU muestra el menu con branding METTA OS."
echo "Al elegir 'Live system' veras un mensaje en consola y volvera al menu."
echo "NO arranca el sistema operativo (no hay kernel en esta imagen)."
if ISO="$(find_metta_iso)"; then
  echo ""
  echo "ISO encontrada: $ISO"
  echo "Boot real:  ./preview/preview-grub.sh --boot-iso"
  echo "         o  ./test-iso.sh \"$ISO\""
else
  echo ""
  echo "Sin ISO METTA OS local. Compila con: ./scripts/ci-build.sh"
fi
echo ""

run_preview() {
  local res="${METTA_GRUB_RES:-1920x1080}"
  local -a preview_flags=(--resolution "$res")
  if [ "${METTA_GRUB_FULLSCREEN:-0}" = "1" ]; then
    preview_flags+=(--full-screen)
  fi
  echo "Tema: $PREVIEW_THEME (${res})"
  grub2-theme-preview "${preview_flags[@]}" --grub-cfg "$CFG" "$PREVIEW_THEME"
}

if command -v grub2-theme-preview >/dev/null 2>&1; then
  run_preview
  exit 0
fi

if preview_install_pip_pkg grub2-theme-preview && command -v grub2-theme-preview >/dev/null 2>&1; then
  run_preview
  exit 0
fi

echo "grub2-theme-preview no disponible." >&2
echo "  pip install grub2-theme-preview   # sin --user en venv" >&2
echo "  pacman -S grub xorriso mtools     # deps en Arch" >&2
echo "Fallback: splash + mockup HTML" >&2
preview_open "$PREVIEW_THEME/splash.png"
preview_open "file://$ROOT/preview/mockup.html"
exit 0
