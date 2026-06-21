#!/bin/bash
# Compile all METTA Tauri apps and install binaries into includes.chroot.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPS_ROOT="$ROOT/apps"
DEST="$ROOT/kali-config/common/includes.chroot/usr/bin"
WRAPPERS="$ROOT/kali-config/common/includes.chroot/usr/lib/metta/bin"

mkdir -p "$DEST" "$WRAPPERS"

THEME_SRC="$ROOT/kali-config/common/includes.chroot/usr/share/metta/metta-theme.css"
THEME_LINK="$APPS_ROOT/metta-theme.css"
ln -sf "$THEME_SRC" "$THEME_LINK"

export PATH="$HOME/.cargo/bin:$PATH"
command -v cargo >/dev/null || {
  if [ -z "${METTA_IN_DOCKER:-}" ] && [ -x "$ROOT/scripts/docker-run.sh" ] && command -v docker >/dev/null 2>&1; then
    echo "[build-all] Rust no encontrado — compilando dentro de Docker..."
    exec "$ROOT/scripts/docker-run.sh" "cd apps && METTA_IN_DOCKER=1 ./build-all.sh"
  fi
  cat >&2 <<EOF
ERROR: Rust/cargo no encontrado.

Opción A — instalar Rust:
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  source \$HOME/.cargo/env
  # deps Arch: sudo ./scripts/setup-host-arch.sh

Opción B — compilar en Docker (si tienes docker):
  ./scripts/docker-run.sh "cd apps && ./build-all.sh"

Opción C — omitir apps (ISO usa stubs):
  METTA_BUILD_APPS=0 ./scripts/ci-build.sh

EOF
  exit 1
}
command -v npm >/dev/null || { echo "ERROR: npm required" >&2; exit 1; }

APPS=(
  metta-control-center
  metta-launcher
  metta-notify
  metta-scanner
  metta-app-store
  metta-updater
  metta-converter
  metta-vpn-manager
  metta-netmap
  metta-welcome
)

build_app() {
  local name="$1"
  local dir="$APPS_ROOT/$name"
  echo "[build-all] $name"
  cd "$dir"
  if [ ! -d node_modules ]; then
    npm ci --prefer-offline --no-audit --no-fund 2>/dev/null || npm install --no-audit --no-fund
  fi
  npm run tauri build
  local bin="$dir/src-tauri/target/release/$name"
  [ -f "$bin" ] || bin="$dir/src-tauri/target/release/${name//-/_}"
  [ -f "$bin" ] || { echo "FALLO: binario no encontrado para $name" >&2; exit 1; }
  install -m 755 "$bin" "$DEST/$name"
}

for app in "${APPS[@]}"; do
  build_app "$app"
done

# CLI helpers
install -m 755 "$ROOT/kali-config/common/includes.chroot/usr/lib/metta/metta-pkg" "$DEST/metta-pkg" 2>/dev/null || true

cat > "$DEST/metta-terminal" << 'EOF'
#!/bin/sh
exec kitty "$@"
EOF
chmod 755 "$DEST/metta-terminal"

cat > "$DEST/metta-notify-send" << 'EOF'
#!/bin/sh
exec metta-notify --send "$@"
EOF
chmod 755 "$DEST/metta-notify-send"

cat > "$DEST/metta-pkg-gui" << 'EOF'
#!/bin/sh
exec metta-app-store --mettapp "$@"
EOF
chmod 755 "$DEST/metta-pkg-gui"

echo "[build-all] OK → $DEST"
