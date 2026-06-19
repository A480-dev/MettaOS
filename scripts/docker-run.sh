#!/bin/bash
# Ejecuta un comando dentro del contenedor metta-os-builder (misma imagen que CI).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCKER_IMAGE="${METTA_DOCKER_IMAGE:-metta-os-builder}"

if ! command -v docker >/dev/null 2>&1; then
  cat >&2 <<EOF
ERROR: docker no está instalado.

Arch Linux:
  sudo pacman -S docker
  sudo systemctl enable --now docker
  sudo usermod -aG docker "\$USER"   # luego cierra sesión

O usa GitHub Actions (push a main) — no necesitas Docker local.

EOF
  exit 1
fi

if [ $# -eq 0 ]; then
  echo "Uso: $0 <comando...>" >&2
  echo "Ej:  $0 ./scripts/generate-assets.sh" >&2
  exit 1
fi

if ! docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1; then
  echo "Construyendo imagen $DOCKER_IMAGE (primera vez, ~5 min)..."
  docker build -t "$DOCKER_IMAGE" -f "$ROOT/docker/Dockerfile.build" "$ROOT/docker"
fi

exec docker run --rm \
  -v "$ROOT:/build" \
  -w /build \
  "$DOCKER_IMAGE" \
  -c "$*"
