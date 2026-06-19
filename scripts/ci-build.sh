#!/bin/bash
# GitHub Actions / CI entry point — full METTA OS build pipeline.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VARIANT="${METTA_VARIANT:-default}"
DOCKER_IMAGE="${METTA_DOCKER_IMAGE:-metta-os-builder}"
RUN_TESTS="${METTA_RUN_TESTS:-1}"
ISO=""
FINGERPRINT=""
STAMP="$ROOT/images/.metta-build-fingerprint"

log() { echo "[ci-build] $*"; }

docker_run() {
  docker run --rm \
    -v "$ROOT:/build" \
    -w /build \
    "$DOCKER_IMAGE" \
    -c "$*"
}

docker_run_priv() {
  docker run --rm --privileged \
    -v "$ROOT:/build" \
    -w /build \
    "$DOCKER_IMAGE" \
    -c "$*"
}

# lb-build and QEMU run as root in Docker — restore ownership for the CI runner
fix_workspace_perms() {
  docker run --rm \
    -v "$ROOT:/build" \
    "$DOCKER_IMAGE" \
    -c "chown -R $(id -u):$(id -g) /build/images /build/chroot /build/test-output 2>/dev/null || true"
}

iso_fingerprint() {
  METTA_VARIANT="$VARIANT" "$ROOT/scripts/iso-build-fingerprint.sh"
}

purge_stale_iso() {
  log "Removing stale ISO artifacts from images/"
  rm -f "$ROOT/images"/metta-os-*.iso "$ROOT/images"/metta-os-*.iso.sha256 "$STAMP"
}

if ! docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1; then
  if ! command -v docker >/dev/null 2>&1; then
    cat >&2 <<EOF
[ci-build] ERROR: docker no está instalado.

  Arch:  sudo pacman -S docker && sudo systemctl enable --now docker
         sudo usermod -aG docker "\$USER"

  Luego: ./scripts/ci-build.sh

  Sin Docker local: haz commit + push a GitHub — Actions construye la ISO.

EOF
    exit 1
  fi
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

FINGERPRINT="$(iso_fingerprint)"
log "Build fingerprint: $FINGERPRINT"

mkdir -p "$ROOT/images"
CACHED_FP=""
[ -f "$STAMP" ] && CACHED_FP="$(tr -d '[:space:]' < "$STAMP")"

EXISTING_ISO=$(find "$ROOT/images" -name 'metta-os-*.iso' 2>/dev/null | head -1 || true)

if [ -n "$EXISTING_ISO" ] && [ "$CACHED_FP" != "$FINGERPRINT" ]; then
  log "WARN: ISO cache fingerprint mismatch (cached=$CACHED_FP current=$FINGERPRINT)"
  purge_stale_iso
  EXISTING_ISO=""
fi

log "Generating assets (inside Docker)..."
if [ "${METTA_SKIP_ASSETS:-0}" = "1" ] && [ -n "$EXISTING_ISO" ] && [ -f "$EXISTING_ISO" ]; then
  log "Skipping generate-assets (METTA_SKIP_ASSETS=1, ISO present)"
elif [ "${METTA_SKIP_ASSETS:-0}" = "1" ]; then
  log "WARN: METTA_SKIP_ASSETS=1 but no ISO — regenerating assets"
  docker_run "./scripts/generate-assets.sh"
else
  docker_run "./scripts/generate-assets.sh"
fi

if [ "${METTA_BUILD_APPS:-0}" = "1" ]; then
  log "Building METTA Tauri apps..."
  docker_run "cd apps && ./build-all.sh"
else
  log "Skipping Tauri apps (METTA_BUILD_APPS=0). Stubs will be used in ISO."
fi

ISO="$EXISTING_ISO"

reuse_iso=0
if [ -n "$ISO" ] && [ -f "$ISO" ] && [ "$CACHED_FP" = "$FINGERPRINT" ]; then
  if [ "${METTA_SKIP_BUILD:-0}" = "1" ] || [ "${METTA_REUSE_ISO:-0}" = "1" ]; then
    log "Validating cached ISO before reuse..."
    if docker_run_priv "./scripts/verify-metta-desktop.sh '' ${ISO#"$ROOT"/}"; then
      reuse_iso=1
    else
      log "WARN: cached ISO failed desktop verification — forcing full rebuild"
      purge_stale_iso
      ISO=""
    fi
  fi
fi

if [ "$reuse_iso" -eq 1 ]; then
  log "Skipping lb-build — reusing existing ISO: $ISO"
elif [ "${METTA_SKIP_BUILD:-0}" = "1" ] || [ "${METTA_REUSE_ISO:-0}" = "1" ]; then
  log "WARN: reuse requested but no valid ISO in images/ — running full lb-build"
  log "Building live ISO (privileged)..."
  docker run --rm --privileged \
    --cap-add SYS_ADMIN \
    -v "$ROOT:/build" \
    -w /build \
    "$DOCKER_IMAGE" \
    -c "./lb-build.sh --variant ${VARIANT} --verbose"
  ISO=$(find "$ROOT/images" -name 'metta-os-*.iso' 2>/dev/null | head -1)
  fix_workspace_perms
else
  log "Building live ISO (privileged)..."
  docker run --rm --privileged \
    --cap-add SYS_ADMIN \
    -v "$ROOT:/build" \
    -w /build \
    "$DOCKER_IMAGE" \
    -c "./lb-build.sh --variant ${VARIANT} --verbose"
  ISO=$(find "$ROOT/images" -name 'metta-os-*.iso' 2>/dev/null | head -1)
  fix_workspace_perms
fi

if [ -z "$ISO" ] || [ ! -f "$ISO" ]; then
  log "ERROR: ISO not found under images/"
  exit 1
fi
log "ISO: $ISO"
printf '%s\n' "$FINGERPRINT" > "$STAMP"
fix_workspace_perms

if [ -d "$ROOT/chroot" ] && [ "${METTA_SKIP_CHROOT_VERIFY:-0}" != "1" ]; then
  log "Verifying branding on chroot..."
  docker_run_priv "./scripts/verify-branding.sh chroot/"
  log "Verifying METTA desktop on chroot..."
  docker_run_priv "./scripts/verify-metta-desktop.sh chroot/"
else
  log "Skipping chroot verify (no chroot/ or METTA_SKIP_CHROOT_VERIFY=1)"
fi

log "Verifying branding on ISO..."
docker_run_priv "./scripts/verify-branding.sh '' ${ISO#"$ROOT"/}"

log "Verifying METTA desktop on ISO..."
docker_run_priv "./scripts/verify-metta-desktop.sh '' ${ISO#"$ROOT"/}"

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
    -c "./test-iso.sh ${ISO#"$ROOT"/}" || {
      log "WARN: QEMU smoke test failed — retrying once..."
      docker run --rm --privileged \
        -e METTA_CI=1 \
        -e METTA_TEST_NO_DISPLAY=1 \
        -e METTA_TEST_TIMEOUT="${METTA_TEST_TIMEOUT:-90}" \
        -e METTA_TEST_UEFI="${METTA_TEST_UEFI:-0}" \
        -v "$ROOT:/build" \
        -w /build \
        "$DOCKER_IMAGE" \
        -c "./test-iso.sh ${ISO#"$ROOT"/}"
    }
else
  log "Skipping QEMU tests (METTA_RUN_TESTS=0)"
fi

fix_workspace_perms

log "Writing checksum..."
sha256sum "$ISO" | tee "${ISO}.sha256"

log "Done: $ISO"
