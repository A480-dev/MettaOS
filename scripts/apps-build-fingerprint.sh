#!/bin/bash
# Fingerprint of METTA Tauri app sources (for CI cache key).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

{
  sha256sum apps/Cargo.toml apps/Cargo.lock apps/build-all.sh 2>/dev/null || true
  find apps/metta-core -type f 2>/dev/null | sort | xargs sha256sum 2>/dev/null || true
  find apps -type f \
    \( -path '*/node_modules/*' -o -path '*/dist/*' -o -path '*/target/*' -o -path '*/.build-cache/*' \) -prune \
    -o -type f -print 2>/dev/null | sort | xargs sha256sum 2>/dev/null || true
} | sha256sum | awk '{print $1}'
