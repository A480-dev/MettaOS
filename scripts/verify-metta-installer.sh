#!/bin/bash
# Verify METTA OS custom installer is baked into chroot or ISO.
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

check_file usr/lib/metta/metta-installer-engine.sh "motor instalador METTA" || FAILED=1
check_file usr/lib/metta/metta-system-postinstall.sh "postinstall METTA" || FAILED=1
check_file usr/share/applications/metta-installer.desktop "desktop instalador" || FAILED=1
check_file etc/polkit-1/rules.d/50-metta-installer.rules "polkit instalador" || FAILED=1
check_grep usr/lib/metta/metta-installer-engine.sh 'unsquashfs' "extracción squashfs" || FAILED=1
check_grep usr/share/applications/metta-installer.desktop 'metta-installer' "launcher instalador" || FAILED=1

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi

echo "OK: instalador METTA verificado en la imagen"
