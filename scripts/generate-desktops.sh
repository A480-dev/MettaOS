#!/bin/bash
# Generate .desktop files for METTA OS 2.0 apps.
set -euo pipefail
DEST="$1"
mkdir -p "$DEST"
gen() {
  local id="$1" name="$2" exec="$3" cat="$4"
  cat > "$DEST/metta-${id}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=METTA OS — $name
Exec=$exec
Icon=/usr/share/icons/metta/128x128/apps/mettaos.png
Categories=$cat;
Terminal=false
StartupNotify=true
EOF
}
gen control-center "METTA Control Center" "metta-control-center" "Settings"
gen launcher "METTA Launcher" "metta-launcher" "Utility"
gen notify "METTA Notify" "metta-notify --daemon" "System"
gen scanner "METTA Network Scanner" "metta-scanner" "Network"
gen app-store "METTA App Store" "metta-app-store" "PackageManager"
gen updater "METTA Updater" "metta-updater" "System"
gen converter "METTA Converter" "metta-converter" "Utility"
gen vpn-manager "METTA VPN Manager" "metta-vpn-manager" "Network"
gen netmap "METTA Net Map" "metta-netmap" "Network"
gen welcome "METTA Welcome" "metta-welcome" "System"
gen pkg-gui "METTA Package Manager" "metta-pkg-gui" "PackageManager"
echo "Desktop files → $DEST"
