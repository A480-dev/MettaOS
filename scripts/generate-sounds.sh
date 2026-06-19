#!/bin/bash
# Generate synthetic METTA OS sound theme (OGG).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/kali-config/common/includes.chroot/usr/share/sounds/metta/stereo"
mkdir -p "$OUT"

python3 "$ROOT/assets/sounds/generate-sounds.py" "$OUT"
echo "Sounds → $OUT"
