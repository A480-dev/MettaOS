#!/bin/sh
# Fallback launcher when Tauri binary is not yet compiled into the ISO.
APP="${0##*/}"
zenity --info --title="METTA OS" --text="$APP no está compilado en esta ISO.\nEjecuta apps/build-all.sh antes del lb build." 2>/dev/null || \
  echo "METTA OS: $APP — compile apps with ./apps/build-all.sh" >&2
exit 0
