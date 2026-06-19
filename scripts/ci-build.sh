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

docker_run() {
  docker run --rm \
    -v "$ROOT:/build" \
    -w /build \
    "$DOCKER_IMAGE" \
    -c "$*"
}

if ! docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1; then
  log "Building Docker image..."
  DOCKERFILE_HASH="$(sha256sum docker/Dockerfile.build | awk '{print $1}')"
  docker build \
    --label "metta.dockerfile-hash=$DOCKERFILE_HASH" \
    -t "$DOCKER_IMAGE" \
    -f docker/Dockerfile.build docker/
else
  DOCKERFILE_HASH="$(sha256sum docker/Dockerfile.build | awk '{print $1}')"
  CACHED_HASH="$(docker inspect --format='{{index .Config.Labels "metta.dockerfile-hash"}}' "$DOCKER_IMAGE" 2>/dev/null || true)"
  if [ "${METTA_REBUILD_DOCKER:-0}" = "1" ] || [ "$DOCKERFILE_HASH" != "$CACHED_HASH" ]; then
    log "Dockerfile changed (or METTA_REBUILD_DOCKER=1) — rebuilding image..."
    docker build \
      --label "metta.dockerfile-hash=$DOCKERFILE_HASH" \
      -t "$DOCKER_IMAGE" \
      -f docker/Dockerfile.build docker/
  else
    log "Using existing Docker image: $DOCKER_IMAGE"
  fi
fi

if [ ! -f "$ROOT/assets/source/metta-logo-source.png" ]; then
  log "ERROR: Missing assets/source/metta-logo-source.png (commit the logo source file)" >&2
  exit 1
fi

log "Generating assets (inside Docker)..."
docker_run "./scripts/generate-assets.sh"

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
