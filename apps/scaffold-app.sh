#!/bin/bash
# Generate a METTA Tauri app from _template.
set -euo pipefail

APPS_ROOT="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$APPS_ROOT/_template"
NAME="${1:-}"
TITLE="${2:-$NAME}"

usage() {
  echo "Uso: $0 <app-id> [Titulo Visible]" >&2
  exit 1
}

[ -n "$NAME" ] || usage
[ -d "$TEMPLATE" ] || { echo "Template missing: $TEMPLATE" >&2; exit 1; }

DEST="$APPS_ROOT/$NAME"
[ ! -e "$DEST" ] || { echo "Exists: $DEST" >&2; exit 1; }

cp -a "$TEMPLATE" "$DEST"
find "$DEST" -type f -print0 | while IFS= read -r -d '' f; do
  sed -i "s/__APP_ID__/$NAME/g; s/__APP_TITLE__/$TITLE/g; s/__APP_CRATE__/${NAME//-/_}/g" "$f"
done
echo "Scaffolded $DEST"
