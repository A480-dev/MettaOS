#!/bin/bash
# Resolve OVMF firmware paths (Debian, Arch edk2-ovmf, Fedora, etc.)
ovmf_find_code() {
  local p
  for p in \
    "${OVMF_CODE:-}" \
    /usr/share/edk2/x64/OVMF_CODE.4m.fd \
    /usr/share/edk2/x64/OVMF_CODE.fd \
    /usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd \
    /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/qemu/OVMF.fd; do
    [ -n "$p" ] && [ -f "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

ovmf_find_vars() {
  local code="${1:-}"
  local dir p
  local candidates=()

  if [ -n "${OVMF_VARS:-}" ] && [ -f "${OVMF_VARS}" ]; then
    echo "${OVMF_VARS}"
    return 0
  fi

  if [ -n "$code" ]; then
    dir="$(dirname "$code")"
    candidates+=(
      "$dir/OVMF_VARS.4m.fd"
      "$dir/OVMF_VARS.fd"
    )
  fi

  candidates+=(
    /usr/share/edk2/x64/OVMF_VARS.4m.fd
    /usr/share/edk2/x64/OVMF_VARS.fd
    /usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd
    /usr/share/OVMF/OVMF_VARS.fd
  )

  for p in "${candidates[@]}"; do
    [ -f "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}
