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
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$APPS_ROOT/target}"
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
  metta-installer
)

ICON_SRC="$ROOT/kali-config/common/includes.chroot/usr/share/icons/metta/256x256/apps/mettaos.png"
ensure_app_icons() {
  local app dir
  for app in "${APPS[@]}"; do
    dir="$APPS_ROOT/$app/src-tauri/icons"
    mkdir -p "$dir"
    if [ ! -f "$dir/icon.png" ] && [ -f "$ICON_SRC" ]; then
      cp "$ICON_SRC" "$dir/icon.png"
    fi
  done
}
ensure_app_icons

CACHE_DIR="${METTA_APPS_CACHE_DIR:-$APPS_ROOT/.build-cache}"
mkdir -p "$CACHE_DIR"

app_source_hash() {
  local name="$1"
  local dir="$APPS_ROOT/$name"
  {
    sha256sum "$APPS_ROOT/Cargo.toml" "$APPS_ROOT/Cargo.lock" 2>/dev/null || true
    find "$APPS_ROOT/metta-core" -type f -name '*.rs' 2>/dev/null | sort | xargs sha256sum 2>/dev/null || true
    find "$dir" \
      \( -path '*/node_modules/*' -o -path '*/dist/*' -o -path '*/target/*' \) -prune \
      -o -type f \( -name '*.rs' -o -name '*.ts' -o -name '*.tsx' -o -name '*.json' -o -name 'Cargo.toml' -o -name 'tauri.conf.json' -o -name 'index.html' \) -print \
      2>/dev/null | sort | xargs sha256sum 2>/dev/null || true
  } | sha256sum | awk '{print $1}'
}

find_release_bin() {
  local name="$1"
  local dir="$2"
  local bin="$CARGO_TARGET_DIR/release/$name"
  [ -f "$bin" ] && { echo "$bin"; return 0; }
  bin="$CARGO_TARGET_DIR/release/${name//-/_}"
  [ -f "$bin" ] && { echo "$bin"; return 0; }
  bin="$dir/src-tauri/target/release/$name"
  [ -f "$bin" ] && { echo "$bin"; return 0; }
  bin="$dir/src-tauri/target/release/${name//-/_}"
  [ -f "$bin" ] && { echo "$bin"; return 0; }
  return 1
}

install_cached_app() {
  local name="$1"
  local dir="$2"
  local bin
  bin="$(find_release_bin "$name" "$dir")" || return 1
  install -m 755 "$bin" "$DEST/$name"
}

build_app() {
  local name="$1"
  local dir="$APPS_ROOT/$name"
  local stamp="$CACHE_DIR/$name.sha256"
  local hash
  hash="$(app_source_hash "$name")"

  if [ -f "$stamp" ] && [ "$(tr -d '[:space:]' < "$stamp")" = "$hash" ]; then
    if install_cached_app "$name" "$dir"; then
      echo "[build-all] $name (cache hit, skip build)"
      return 0
    fi
  fi

  echo "[build-all] $name"
  cd "$dir"
  if [ ! -d node_modules ]; then
    npm ci --prefer-offline --no-audit --no-fund 2>/dev/null || npm install --no-audit --no-fund
  fi
  npm run tauri build
  local bin="$CARGO_TARGET_DIR/release/$name"
  [ -f "$bin" ] || bin="$CARGO_TARGET_DIR/release/${name//-/_}"
  [ -f "$bin" ] || bin="$dir/src-tauri/target/release/$name"
  [ -f "$bin" ] || bin="$dir/src-tauri/target/release/${name//-/_}"
  [ -f "$bin" ] || { echo "FALLO: binario no encontrado para $name" >&2; exit 1; }
  install -m 755 "$bin" "$DEST/$name"
  printf '%s\n' "$hash" > "$stamp"
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
