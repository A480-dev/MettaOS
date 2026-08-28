#!/bin/sh
# METTA OS — post-install inside target system chroot (installer-agnostic).
set -eu

CHROOT="${1:-}"
if [ -z "$CHROOT" ] || [ ! -d "$CHROOT/etc" ]; then
  echo "ERROR: usage: metta-system-postinstall.sh <chroot>" >&2
  exit 1
fi

echo "INFO: METTA system post-install in $CHROOT"

if [ -x "$CHROOT/kali-finish-install" ]; then
  chroot "$CHROOT" /kali-finish-install || echo "WARN: kali-finish-install failed" >&2
  rm -f "$CHROOT/kali-finish-install"
fi

rm -f "$CHROOT/etc/apt/sources.list"
find "$CHROOT/etc/apt/sources.list.d" -mindepth 1 -maxdepth 1 -delete 2>/dev/null || true
cat > "$CHROOT/etc/apt/sources.list.d/kali.sources" << 'EOF'
# See https://www.kali.org/docs/general-use/kali-apt-sources/
Types: deb
URIs: http://http.kali.org/kali/
Suites: kali-rolling
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/kali-archive-keyring.gpg
EOF
chroot "$CHROOT" apt-get update 2>/dev/null || echo "WARN: apt-get update failed" >&2

if [ -x "$CHROOT/usr/lib/metta/install-plasma-defaults.sh" ]; then
  chroot "$CHROOT" /usr/lib/metta/install-plasma-defaults.sh || true
fi

mkdir -p "$CHROOT/etc/sddm.conf.d"
cat > "$CHROOT/etc/sddm.conf.d/metta.conf" << 'EOF'
[General]
DisplayServer=x11

[Theme]
Current=metta
EOF
rm -f "$CHROOT/etc/sddm.conf.d/autologin.conf" 2>/dev/null || true

for f in \
  "$CHROOT/etc/xdg/autostart/calamares-desktop-icon.desktop" \
  "$CHROOT/etc/xdg/autostart/live-settings.desktop"
do
  rm -f "$f"
done

if command -v systemctl >/dev/null 2>&1 && [ -d "$CHROOT/etc/systemd/system" ]; then
  chroot "$CHROOT" systemctl enable sddm.service 2>/dev/null || true
  chroot "$CHROOT" systemctl disable lightdm.service 2>/dev/null || true
  chroot "$CHROOT" systemctl enable metta-bcm4364-firmware.service 2>/dev/null || true
fi

if [ -f "$CHROOT/etc/os-release" ]; then
  sed -i \
    -e 's/Kali Linux/METTA OS/g' \
    -e 's/Kali GNU\/Linux/METTA OS/g' \
    "$CHROOT/etc/os-release" 2>/dev/null || true
fi

echo "INFO: METTA system post-install complete"
exit 0
