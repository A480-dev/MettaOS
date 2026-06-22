#!/bin/bash
# Verify Calamares METTA installer configuration in chroot or ISO squashfs.
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

check_not_file() {
  local path="$1"
  local label="$2"
  if [ -e "$TARGET/$path" ]; then
    echo "FALLO: $label aún presente ($path)" >&2
    return 1
  fi
  return 0
}

FAILED=0

resolve_target

check_file etc/calamares/settings.conf "Calamares settings.conf" || FAILED=1
check_grep etc/calamares/settings.conf '^branding: metta' "branding METTA en settings" || FAILED=1
check_file etc/calamares/modules/unpackfs.conf "Calamares unpackfs" || FAILED=1
check_file etc/calamares/modules/displaymanager.conf "Calamares displaymanager" || FAILED=1
check_grep etc/calamares/modules/displaymanager.conf 'startxfce4' "sesión XFCE en displaymanager" || FAILED=1
check_file etc/lightdm/lightdm.conf.d/metta-wayland.conf "LightDM session default" || FAILED=1
check_grep etc/lightdm/lightdm.conf.d/metta-wayland.conf 'user-session=' "LightDM user-session" || FAILED=1
check_file etc/calamares/branding/metta/branding.desc "branding.desc METTA" || FAILED=1
check_file etc/calamares/branding/metta/stylesheet.qss "stylesheet METTA" || FAILED=1
check_file etc/calamares/branding/metta/icon.png "icono Calamares" || FAILED=1
check_file etc/calamares/branding/metta/splash.png "splash Calamares" || FAILED=1
check_file usr/bin/calamares-install-metta "launcher Calamares METTA" || FAILED=1
check_file usr/share/applications/calamares-install-metta.desktop "desktop entry instalador" || FAILED=1
check_file usr/share/calamares/helpers/metta-postinstall "helper postinstall" || FAILED=1
check_file kali-finish-install "kali-finish-install en live" || FAILED=1
check_file usr/lib/metta/install-bcm4364-firmware.sh "instalador firmware BCM4364" || FAILED=1
check_file etc/systemd/system/metta-bcm4364-firmware.service "servicio firmware BCM4364" || FAILED=1
check_not_file etc/calamares/branding/debian "branding Debian de Calamares" || FAILED=1
check_not_file usr/bin/calamares-install-debian "launcher Debian de Calamares" || FAILED=1

if [ -f "$TARGET/var/lib/dpkg/status" ] && grep -q 'Package: calamares-settings-debian' "$TARGET/var/lib/dpkg/status" 2>/dev/null; then
  if grep -A2 'Package: calamares-settings-debian' "$TARGET/var/lib/dpkg/status" | grep -q 'Status: install ok installed'; then
    echo "FALLO: calamares-settings-debian sigue instalado" >&2
    FAILED=1
  fi
fi

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi

echo "OK: instalador Calamares METTA verificado"
