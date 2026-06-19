#!/bin/bash
# Fingerprint of inputs that affect the live ISO (not CI scripts like verify-branding.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

{
  find auto kali-config assets/source assets/branding assets/wallpaper assets/sounds assets/plymouth apps \
    lb-build.sh build.sh docker/Dockerfile.build \
    -type f 2>/dev/null | sort
  echo "variant=${METTA_VARIANT:-default}"
} | sha256sum | awk '{print $1}'
