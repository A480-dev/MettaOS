#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHROOT="${1:-$ROOT/chroot}"
ISO="${2:-}"

scan_path() {
  local path="$1"
  local exclude_re='/(var/lib/apt|var/lib/dpkg|usr/share/keyrings|usr/share/doc/kali-archive-keyring|etc/apt/sources\.list|etc/apt/sources\.list\.d)/'

  grep -rni 'kali' "$path" \
    --exclude-dir='{apt,dpkg,keyrings}' \
    2>/dev/null | grep -viE \
    'kali-rolling|kali-linux|kali-archive|kali-defaults|kali-menu|kali-debtags|kali-root|kali-desktop|kali-tools|kali-meta|/usr/bin/|\.deb:|filename=|Package:|Source:' \
    | grep -viE "$exclude_re" || true
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
  echo "FALLO: referencias visibles a 'kali' encontradas:" >&2
  echo "$HITS" >&2
  exit 1
fi

echo "OK: sin referencias visibles a 'kali' en rutas de usuario"
