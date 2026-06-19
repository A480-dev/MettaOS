#!/bin/bash
# Dependencias en el host para desarrollo METTA OS (Arch Linux).
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Ejecuta con sudo: sudo $0" >&2
  exit 1
fi

echo "== METTA OS — dependencias host (Arch) =="

pacman -Sy --needed --noconfirm \
  python-pillow python-numpy python-scipy python-soundfile \
  imagemagick librsvg \
  qemu-system-x86 edk2-ovmf \
  nodejs npm \
  squashfs-tools \
  base-devel openssl appmenu-gtk-module webkit2gtk-4.1 \
  gtk3 libayatana-appindicator libappindicator-gtk3 librsvg \
  wget git

if ! command -v docker >/dev/null 2>&1; then
  echo ""
  echo "Docker no instalado. Para build ISO local:"
  echo "  pacman -S docker"
  echo "  systemctl enable --now docker"
  echo "  usermod -aG docker \$USER   # cierra sesión y vuelve a entrar"
  echo ""
  echo "Alternativa: push a GitHub y deja que Actions construya la ISO."
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo ""
  echo "Rust no instalado. Para compilar apps Tauri como usuario normal:"
  echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
  echo "  source \$HOME/.cargo/env"
fi

echo ""
echo "OK. Como usuario normal:"
echo "  ./scripts/generate-assets.sh"
echo "  METTA_BUILD_APPS=1 ./apps/build-all.sh    # requiere Rust + deps Tauri"
echo "  ./scripts/ci-build.sh                     # requiere Docker"
