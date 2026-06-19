#!/bin/bash
# Shared helpers for preview scripts
preview_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

preview_open() {
  local target="$1"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$target" >/dev/null 2>&1 &
  elif command -v open >/dev/null 2>&1; then
    open "$target" >/dev/null 2>&1 &
  else
    echo "Abre manualmente: $target"
  fi
}

preview_install_pip_pkg() {
  local pkg="$1"
  local pip_flags=()

  if [ -z "${VIRTUAL_ENV:-}" ] && [ -z "${CONDA_DEFAULT_ENV:-}" ]; then
    pip_flags=(--user)
    export PATH="$HOME/.local/bin:$PATH"
  fi

  if python3 -m pip install "${pip_flags[@]}" "$pkg" 2>/dev/null; then
    return 0
  fi
  if command -v pip3 >/dev/null 2>&1 && pip3 install "${pip_flags[@]}" "$pkg" 2>/dev/null; then
    return 0
  fi
  if command -v pip >/dev/null 2>&1 && pip install "${pip_flags[@]}" "$pkg" 2>/dev/null; then
    return 0
  fi
  return 1
}
