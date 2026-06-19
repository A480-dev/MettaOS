#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=preview/lib.sh
source "$ROOT/preview/lib.sh"

MOCKUP="$ROOT/preview/mockup.html"

if [ ! -f "$MOCKUP" ]; then
  echo "ERROR: no existe $MOCKUP" >&2
  exit 1
fi

if [ ! -f "$ROOT/preview/assets/metta-icon-512.png" ]; then
  echo "Generando assets..." >&2
  "$ROOT/scripts/generate-assets.sh"
fi

echo "Abriendo mockup HTML (Nivel 0)..."
preview_open "file://$MOCKUP"
