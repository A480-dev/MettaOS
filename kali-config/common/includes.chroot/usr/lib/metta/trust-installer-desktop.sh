#!/bin/sh
# Mark METTA installer desktop shortcuts as trusted (Xfce requires this).
set -e

mark_trusted() {
    f="$1"
    [ -f "$f" ] || return 0
    chmod 755 "$f" 2>/dev/null || chmod 644 "$f" 2>/dev/null || true
    if command -v gio >/dev/null 2>&1; then
        gio set "$f" metadata::trusted true 2>/dev/null || true
    fi
}

for f in \
    /etc/skel/Desktop/"Instalar METTA OS.desktop" \
    /usr/share/applications/calamares-install-metta.desktop
do
    mark_trusted "$f"
done

for home in /home/*; do
    [ -d "$home" ] || continue
    mark_trusted "$home/Desktop/Instalar METTA OS.desktop"
done
