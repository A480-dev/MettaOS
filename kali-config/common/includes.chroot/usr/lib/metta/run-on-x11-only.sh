#!/bin/sh
# Run command only on X11 sessions (skip on Wayland).
[ "${XDG_SESSION_TYPE:-x11}" = "x11" ] || exit 0
exec "$@"
