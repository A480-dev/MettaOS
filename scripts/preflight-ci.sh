#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.." 2>/dev/null || cd /c/Users/USER/Desktop/MettaOS
fail=0
check_syntax() {
  if ! bash -n "$1"; then
    echo "SYNTAX FAIL: $1"
    fail=1
  fi
}
for f in \
  apps/build-all.sh \
  scripts/ci-build.sh \
  scripts/verify-metta-desktop.sh \
  scripts/verify-metta-installer.sh \
  scripts/verify-branding.sh \
  scripts/iso-build-fingerprint.sh \
  scripts/generate-assets.sh \
  kali-config/common/includes.chroot/usr/lib/metta/install-plasma-defaults.sh \
  kali-config/common/includes.chroot/usr/lib/metta/plasma-live-setup.sh \
  kali-config/common/includes.chroot/usr/lib/metta/metta-installer-engine.sh \
  kali-config/common/includes.chroot/usr/lib/metta/metta-system-postinstall.sh \
  kali-config/common/hooks/live/0100-metta-plasma.chroot \
  kali-config/common/hooks/live/0150-metta-theme.chroot \
  kali-config/common/hooks/live/0160-metta-v2-desktop.chroot \
  kali-config/common/hooks/live/0180-metta-installer.chroot \
  kali-config/common/hooks/live/0990-metta-overrides.chroot \
  kali-config/common/includes.chroot/usr/lib/live/config/0033-metta-plasma-skel \
  preview/preview-desktop.sh
do
  check_syntax "$f"
done

ROOT=kali-config/common/includes.chroot
for p in \
  usr/lib/metta/metta-installer-engine.sh \
  usr/lib/metta/metta-system-postinstall.sh \
  usr/share/applications/metta-installer.desktop \
  etc/polkit-1/rules.d/50-metta-installer.rules \
  usr/share/color-schemes/Metta-Dark.colors \
  usr/lib/metta/plasma-live-setup.sh \
  etc/xdg/autostart/metta-plasma-setup.desktop \
  etc/xdg/autostart/metta-plasma-setup-delayed.desktop \
  usr/lib/metta/install-plasma-defaults.sh \
  usr/share/plasma/look-and-feel/org.mettaos.desktop/metadata.desktop \
  etc/xdg/plasma-org.kde.plasma.desktop-appletsrc \
  etc/live/config.conf.d/metta.conf \
  etc/xdg/kdeglobals \
  etc/xdg/plasmarc \
  etc/skel/.config/kdeglobals
do
  if [ ! -f "$ROOT/$p" ]; then
    echo "MISSING: $p"
    fail=1
  fi
done

grep -q "org.mettaos.desktop" "$ROOT/etc/xdg/plasmarc" || { echo "FAIL plasmarc"; fail=1; }
grep -q "Metta-Dark" "$ROOT/etc/xdg/kdeglobals" || { echo "FAIL kdeglobals"; fail=1; }
grep -q "Papirus-Dark" "$ROOT/etc/skel/.config/kdeglobals" || { echo "FAIL skel kdeglobals"; fail=1; }
grep -q 'LIVE_USERNAME="metta"' "$ROOT/etc/live/config.conf.d/metta.conf" || { echo "FAIL metta.conf"; fail=1; }

test -f apps/metta-installer/src-tauri/tauri.conf.json
test -f apps/metta-installer/package-lock.json
test -f kali-config/variant-kde/package-lists/kali.list.chroot
test -f kali-config/variant-kde-light/package-lists/kali.list.chroot
test ! -e scripts/verify-calamares.sh
test ! -e kali-config/common/includes.chroot/usr/bin/calamares-install-metta

if grep -qx "grub-efi-amd64" kali-config/common/package-lists/metta.list.chroot; then
  echo "FAIL: grub-efi-amd64 metapackage still listed"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "PREFLIGHT FAILED"
  exit 1
fi
echo "PREFLIGHT OK"
