#!/bin/bash
set -euo pipefail

ISO="${1:-}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/test-output"
BOOT_LOG="$OUT/boot.log"
TIMEOUT="${METTA_TEST_TIMEOUT:-120}"
RUN_UEFI="${METTA_TEST_UEFI:-1}"

usage() {
  echo "Uso: $0 <archivo.iso>" >&2
  exit 1
}

[ -n "$ISO" ] && [ -f "$ISO" ] || usage

if [ -n "${METTA_CI:-}" ]; then
  TIMEOUT="${METTA_TEST_TIMEOUT:-90}"
  RUN_UEFI="${METTA_TEST_UEFI:-0}"
fi

mkdir -p "$OUT"
: > "$BOOT_LOG"

if [ -n "${METTA_CI:-}" ]; then
  QEMU_OPTS=(-m 2048 -smp 2 -cdrom "$ISO")
else
  QEMU_OPTS=(-m 4096 -smp 2 -cdrom "$ISO")
fi
KVM_OPTS=()
if [ -r /dev/kvm ]; then
  KVM_OPTS=(-enable-kvm)
else
  KVM_OPTS=(-accel tcg)
fi

DISPLAY_OPTS=()
if [ -n "${DISPLAY:-}" ] && [ -z "${METTA_TEST_NO_DISPLAY:-}" ]; then
  DISPLAY_OPTS=(-display gtk)
else
  DISPLAY_OPTS=(-nographic)
fi

run_qemu_test() {
  local mode="$1"
  shift
  local extra=("$@")
  local log="$OUT/boot-${mode}.log"
  local pidfile="$OUT/qemu-${mode}.pid"

  : > "$log"
  echo "=== Test QEMU ($mode) ==="

  qemu-system-x86_64 \
    "${KVM_OPTS[@]}" \
    "${QEMU_OPTS[@]}" \
    "${DISPLAY_OPTS[@]}" \
    -serial "file:$log" \
    -monitor "unix:$OUT/qemu-${mode}.sock,server,nowait" \
    "${extra[@]}" &

  echo $! > "$pidfile"
  local pid
  pid=$(cat "$pidfile")

  local wait_secs=(30 60 90)
  if [ -n "${METTA_CI:-}" ]; then
    wait_secs=(45)
  fi

  local i=0
  local n=${#wait_secs[@]}

  for t in "${wait_secs[@]}"; do
    i=$((i + 1))
    sleep "$t" 2>/dev/null || sleep 30
    if [ -S "$OUT/qemu-${mode}.sock" ]; then
      if [ "$i" -eq "$n" ]; then
        {
          printf 'screendump %s/screenshot-%s-%ss.ppm\n' "$OUT" "$mode" "$t"
          printf 'quit\n'
        } | nc -U -N "$OUT/qemu-${mode}.sock" 2>/dev/null || true
      else
        printf 'screendump %s/screenshot-%s-%ss.ppm\n' "$OUT" "$mode" "$t" \
          | nc -U -N "$OUT/qemu-${mode}.sock" 2>/dev/null || true
      fi
    fi
    [ "$t" -ge "$TIMEOUT" ] && break
  done

  sleep 5
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true

  if grep -qiE 'Kernel panic — not syncing|Kernel panic - not syncing|Oops:|BUG: unable to handle' "$log"; then
    echo "FALLO ($mode): error crítico en boot.log" >&2
    tail -50 "$log" >&2
    return 1
  fi

  cat "$log" >> "$BOOT_LOG"
  echo "OK ($mode): arranque sin panic en ${TIMEOUT}s"
  return 0
}

FAILED=0

# BIOS boot
run_qemu_test bios -boot d || FAILED=1

# UEFI boot
# shellcheck source=scripts/ovmf-paths.sh
source "$ROOT/scripts/ovmf-paths.sh"
OVMF="$(ovmf_find_code || true)"
OVMF_VARS=""
if [ -n "$OVMF" ]; then
  OVMF_VARS="$(ovmf_find_vars "$OVMF" || true)"
fi

if [ "$RUN_UEFI" = "1" ] && [ -n "$OVMF" ] && [ -f "$OVMF" ]; then
  cp -f "$OVMF_VARS" "$OUT/OVMF_VARS.fd" 2>/dev/null || touch "$OUT/OVMF_VARS.fd"
  run_qemu_test uefi \
    -machine q35 \
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF" \
    -drive "if=pflash,format=raw,file=$OUT/OVMF_VARS.fd" \
    -boot d || FAILED=1
else
  echo "WARN: OVMF no encontrado, omitiendo test UEFI" >&2
fi

if [ "$FAILED" -ne 0 ]; then
  echo "FALLO: uno o más tests QEMU fallaron" >&2
  exit 1
fi

echo "OK: tests QEMU completados. Logs en $OUT/"
