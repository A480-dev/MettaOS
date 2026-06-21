#!/bin/bash
# Check user-visible Kali branding (not internal package metadata or wordlists).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHROOT="${1:-$ROOT/chroot}"
ISO="${2:-}"

# Patterns that indicate visible Kali branding to end users
BRAND_RE='Kali Linux|Kali GNU|Kali Live|<Name>[^<]*Kali|LIVE_USERNAME="kali"|kali-motd|emblem-kali|gtk-theme-name="Kali-|colorScheme=Kali-|LogoPath=emblem-kali'

# User-facing paths only (skip wordlists, kernel, ssl, internal menu categories)
SCAN_REL_PATHS=(
  etc/issue
  etc/issue.net
  etc/motd
  etc/os-release
  etc/live
  etc/lightdm
  etc/skel
  etc/neofetch
  etc/firefox-esr
  usr/share/applications
  usr/share/xfce4
  usr/share/lightdm
  usr/share/plymouth
  usr/share/metta
  usr/share/pixmaps
  usr/share/icons/metta
  usr/share/themes/Metta-Dark
  boot/grub
)

filter_hits() {
  grep -viE \
    'kali-rolling|kali-linux-|kali-archive|kali-defaults|kali-debtags|kali-root|kali-desktop|kali-tools|kali-meta|kali-menu|Category>kali-|kali\.org/view\.php|Forked by Kali|/etc/ssl/kali|kali_wide_compatibility|kali_strong_security|sd_kali|#.*kali|kali_groups|kali-user-setup|kali\.postinst|kali-finish-install|kali-vm|kali-hacks|kali-themes|kali\.sh:|kali-themes\.sh|kali\.js:|kali\.cnf|linux-image.*\+kali|System\.map.*\+kali|reboot-required\.pkgs|unicornscan|theHarvester|wordlists|names_small|dns-big|dns-names|kaliningrad|kalithies|chakali|fotokeren|zakkalife|cikalideaz|kaliyum|kalimpong|sayasukalirik|fakalipit|wwwjekinamekaliteromoschato|kalintv6|kalinovsky' \
    || true
}

scan_path() {
  local root="$1"
  local hits=""

  for rel in "${SCAN_REL_PATHS[@]}"; do
    local target="$root/$rel"
    [ -e "$target" ] || continue
    hits+=$(grep -rniE "$BRAND_RE" "$target" 2>/dev/null || true)
    hits+=$'\n'
  done

  # Login shell branding
  if [ -d "$root/etc/profile.d" ]; then
    hits+=$(grep -rniE 'kali-motd|Kali Linux|Kali GNU' "$root/etc/profile.d" 2>/dev/null || true)
    hits+=$'\n'
  fi

  # XDG menus — only visible <Name> lines, not Category IDs
  if [ -d "$root/etc/xdg" ]; then
    hits+=$(grep -rniE '<Name>[^<]*Kali|Kali Linux|Kali GNU' "$root/etc/xdg" 2>/dev/null || true)
    hits+=$'\n'
  fi

  printf '%s' "$hits" | filter_hits | sed '/^[[:space:]]*$/d'
}

if [ -n "$ISO" ] && [ -f "$ISO" ]; then
  MNT=$(mktemp -d)
  trap 'umount "$MNT" 2>/dev/null; rmdir "$MNT" 2>/dev/null' EXIT
  mount -o loop,ro "$ISO" "$MNT"
  HITS=$(scan_path "$MNT")
elif [ -d "$CHROOT" ]; then
  HITS=$(scan_path "$CHROOT")
else
  echo "Uso: $0 [chroot_dir] [iso_file]" >&2
  echo "  o bien: $0 /path/to/chroot" >&2
  echo "  o bien: $0 '' /path/to/metta-os.iso" >&2
  exit 1
fi

if [ -n "$HITS" ]; then
  echo "FALLO: referencias visibles a branding Kali encontradas:" >&2
  echo "$HITS" >&2
  exit 1
fi

echo "OK: sin branding Kali visible en rutas de usuario"

if [ -n "$ISO" ] && [ -f "$ISO" ]; then
  "$ROOT/scripts/verify-calamares.sh" "" "$ISO"
elif [ -d "$CHROOT" ]; then
  "$ROOT/scripts/verify-calamares.sh" "$CHROOT"
fi
