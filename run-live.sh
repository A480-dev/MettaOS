#!/bin/bash
# Arranca METTA OS live en QEMU para uso interactivo (no cierra solo).
set -euo pipefail

ISO="${1:-}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

usage() {
  cat <<EOF
Uso: $0 <metta-os.iso> [bios|uefi]

Arranca la ISO en QEMU con ventana gráfica y la deja abierta hasta que cierres.

Ejemplo:
  $0 metta-os-default-amd64/metta-os-1.0-amd64.iso
  $0 metta-os-default-amd64/metta-os-1.0-amd64.iso uefi
EOF
  exit 1
}

[ -n "$ISO" ] && [ -f "$ISO" ] || usage

MODE="${2:-bios}"
MEM="${METTA_QEMU_MEM:-4096}"
SMP="${METTA_QEMU_SMP:-2}"

KVM_OPTS=()
if [ -r /dev/kvm ]; then
  KVM_OPTS=(-enable-kvm)
else
  KVM_OPTS=(-accel tcg)
fi

DISPLAY_OPTS=(-display gtk)
if [ -z "${DISPLAY:-}" ]; then
  echo "WARN: DISPLAY no definido; usando -nographic (Ctrl+a x para salir)" >&2
  DISPLAY_OPTS=(-nographic)
fi

QEMU_OPTS=(-m "$MEM" -smp "$SMP" -cdrom "$ISO" -boot d)

case "$MODE" in
  bios)
    echo "Arrancando METTA OS (BIOS) — cierra la ventana QEMU para salir."
    exec qemu-system-x86_64 "${KVM_OPTS[@]}" "${QEMU_OPTS[@]}" "${DISPLAY_OPTS[@]}"
    ;;
  uefi)
    # shellcheck source=scripts/ovmf-paths.sh
    source "$ROOT/scripts/ovmf-paths.sh"
    OVMF="$(ovmf_find_code)" || {
      echo "ERROR: OVMF no encontrado (Arch: sudo pacman -S edk2-ovmf)" >&2
      exit 1
    }
    OVMF_VARS="$(ovmf_find_vars "$OVMF")" || {
      echo "ERROR: OVMF_VARS no encontrado" >&2
      exit 1
    }
    VAR_COPY="$ROOT/test-output/OVMF_VARS_live.fd"
    mkdir -p "$ROOT/test-output"
    cp -f "$OVMF_VARS" "$VAR_COPY" 2>/dev/null || touch "$VAR_COPY"
    echo "Arrancando METTA OS (UEFI) — cierra la ventana QEMU para salir."
    exec qemu-system-x86_64 "${KVM_OPTS[@]}" "${QEMU_OPTS[@]}" "${DISPLAY_OPTS[@]}" \
      -machine q35 \
      -drive "if=pflash,format=raw,readonly=on,file=$OVMF" \
      -drive "if=pflash,format=raw,file=$VAR_COPY"
    ;;
  *)
    echo "Modo desconocido: $MODE (usa bios o uefi)" >&2
    exit 1
    ;;
esac
