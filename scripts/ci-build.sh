#!/bin/bash
# GitHub Actions / CI entry point — full METTA OS build pipeline.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VARIANT="${METTA_VARIANT:-default}"
DOCKER_IMAGE="${METTA_DOCKER_IMAGE:-metta-os-builder}"
RUN_TESTS="${METTA_RUN_TESTS:-1}"
ISO=""

log() { echo "[ci-build] $*"; }

log "Variant: $VARIANT"
log "Generating assets..."
./scripts/generate-assets.sh

log "Building Docker image..."
docker build -t "$DOCKER_IMAGE" -f docker/Dockerfile.build docker/

log "Building live ISO (privileged)..."
docker run --rm --privileged \
  --cap-add SYS_ADMIN \
  -v "$ROOT:/build" \
  -w /build \
  "$DOCKER_IMAGE" \
  -c "./lb-build.sh --variant ${VARIANT} --verbose"

ISO=$(find "$ROOT/images" -name 'metta-os-*.iso' 2>/dev/null | head -1)
if [ -z "$ISO" ] || [ ! -f "$ISO" ]; then
  log "ERROR: ISO not found under images/"
  exit 1
fi
log "ISO: $ISO"

log "Verifying branding on chroot..."
docker run --rm --privileged \
  -v "$ROOT:/build" \
  -w /build \
  "$DOCKER_IMAGE" \
  -c "./scripts/verify-branding.sh chroot/"

log "Verifying branding on ISO..."
docker run --rm --privileged \
  -v "$ROOT:/build" \
  -w /build \
  "$DOCKER_IMAGE" \
  -c "./scripts/verify-branding.sh '' ${ISO#"$ROOT"/}"

if [ "$RUN_TESTS" = "1" ]; then
  log "QEMU smoke test..."
  docker run --rm --privileged \
    -e METTA_CI=1 \
    -e METTA_TEST_NO_DISPLAY=1 \
    -e METTA_TEST_TIMEOUT="${METTA_TEST_TIMEOUT:-90}" \
    -e METTA_TEST_UEFI="${METTA_TEST_UEFI:-0}" \
    -v "$ROOT:/build" \
    -w /build \
    "$DOCKER_IMAGE" \
    -c "./test-iso.sh ${ISO#"$ROOT"/}"
else
  log "Skipping QEMU tests (METTA_RUN_TESTS=0)"
fi

log "Writing checksum..."
sha256sum "$ISO" | tee "${ISO}.sha256"

log "Done: $ISO"
