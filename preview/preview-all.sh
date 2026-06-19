#!/bin/bash
# Ejecuta todos los previews disponibles en este host (Nivel 0 + fallbacks).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "== METTA OS preview =="
"$ROOT/scripts/generate-assets.sh"

echo ""
echo "--- Nivel 0: mockup HTML ---"
"$ROOT/preview/preview-html.sh"

echo ""
echo "--- Nivel 1a: GRUB ---"
"$ROOT/preview/preview-grub.sh" || true

echo ""
echo "--- Nivel 1b: Plymouth (requiere sudo + plymouth) ---"
if [ "$(id -u)" -eq 0 ]; then
  "$ROOT/preview/preview-plymouth.sh" || true
else
  echo "Omitido (ejecuta: sudo ./preview/preview-plymouth.sh)"
fi

echo ""
echo "--- Nivel 1c: Escritorio ---"
"$ROOT/preview/preview-desktop.sh" || true

echo ""
echo "Listo. Gate final (ISO): ./scripts/ci-build.sh"
