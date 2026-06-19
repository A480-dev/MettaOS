#!/bin/sh
# Background apt update check; notify if upgrades available.
set -e

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq 2>/dev/null || exit 0
count="$(apt list --upgradable 2>/dev/null | grep -c upgradable || true)"
[ "$count" -gt 1 ] || exit 0

if command -v metta-notify-send >/dev/null 2>&1; then
  metta-notify-send --app=updater --title="Actualizaciones disponibles" \
    --body="$((count - 1)) paquetes pueden actualizarse" --action=open-updater
fi
