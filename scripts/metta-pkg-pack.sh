#!/bin/bash
# Pack a directory into a .mettapp SquashFS bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="${1:-}"
output="${2:-}"

usage() {
  echo "Uso: $0 <directorio-app> [salida.mettapp]" >&2
  exit 1
}

[ -n "$source_dir" ] && [ -d "$source_dir" ] || usage
[ -f "$source_dir/META/manifest.json" ] || { echo "FALLO: META/manifest.json requerido" >&2; exit 1; }
[ -x "$source_dir/AppRun" ] || chmod +x "$source_dir/AppRun" 2>/dev/null || true

if [ -z "$output" ]; then
  name="$(python3 -c "import json;print(json.load(open('$source_dir/META/manifest.json'))['id'].replace('.','_'))")"
  output="${name}.mettapp"
fi

mksquashfs "$source_dir" "$output" -noappend -comp xz -all-root
echo "OK: $output"
