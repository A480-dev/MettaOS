#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

# En GitHub Actions usar el pipeline CI dedicado
if [ -n "${GITHUB_ACTIONS:-}" ]; then
  exec "$ROOT/scripts/ci-build.sh"
fi
IMAGE="images/metta-os-1.0-amd64.iso"
DOCKER_IMAGE="${METTA_DOCKER_IMAGE:-metta-os-builder}"
USE_DOCKER="${METTA_USE_DOCKER:-auto}"
RUN_TESTS="${METTA_RUN_TESTS:-1}"

detect_docker() {
  if [ "$USE_DOCKER" = "0" ] || [ "$USE_DOCKER" = "false" ]; then
    return 1
  fi
  if [ "$USE_DOCKER" = "1" ] || [ "$USE_DOCKER" = "true" ]; then
    return 0
  fi
  ! grep -qE '^ID=debian|^ID_LIKE=.*debian' /usr/lib/os-release 2>/dev/null
}

echo "== METTA OS build pipeline =="

echo "[1/5] Generating assets..."
if detect_docker; then
  if ! docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1; then
    echo "Building Docker image $DOCKER_IMAGE..."
    docker build -t "$DOCKER_IMAGE" -f "$ROOT/docker/Dockerfile.build" "$ROOT/docker"
  fi
  docker run --rm -v "$ROOT:/build" -w /build "$DOCKER_IMAGE" -c "./scripts/generate-assets.sh"
else
  "$ROOT/scripts/generate-assets.sh"
fi

echo "[2/5] Building ISO..."
if detect_docker; then
  docker run --rm --privileged \
    -v "$ROOT:/build" \
    -w /build \
    "$DOCKER_IMAGE" \
    -c "./lb-build.sh --variant default --verbose"
else
  cd "$ROOT"
  ./lb-build.sh --variant default --verbose
fi

if [ ! -f "$ROOT/$IMAGE" ]; then
  IMAGE=$(find "$ROOT/images" -name 'metta-os-*.iso' 2>/dev/null | head -1)
fi

if [ -z "$IMAGE" ] || [ ! -f "$ROOT/$IMAGE" ]; then
  echo "ERROR: ISO no encontrada en images/" >&2
  exit 1
fi

echo "[3/5] ISO generada: $ROOT/$IMAGE"

if [ "$RUN_TESTS" = "1" ]; then
  echo "[4/5] Running QEMU tests..."
  if detect_docker; then
    docker run --rm --privileged \
      -v "$ROOT:/build" \
      -w /build \
      "$DOCKER_IMAGE" \
      -c "./test-iso.sh $IMAGE" || {
        echo "WARN: tests QEMU fallaron (continuando checksum)" >&2
      }
  else
    "$ROOT/test-iso.sh" "$ROOT/$IMAGE" || {
      echo "WARN: tests QEMU fallaron (continuando checksum)" >&2
    }
  fi
else
  echo "[4/5] Tests omitidos (METTA_RUN_TESTS=0)"
fi

echo "[5/5] Checksum..."
sha256sum "$ROOT/$IMAGE" | tee "$ROOT/${IMAGE}.sha256"

echo ""
echo "=== METTA OS build complete ==="
echo "ISO:     $ROOT/$IMAGE"
echo "SHA256:  $ROOT/${IMAGE}.sha256"
