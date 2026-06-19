#!/bin/sh
# Install METTA OS Xfce defaults system-wide and in /etc/skel (idempotent).

METTA_XFCE="/usr/share/metta/xfce"
WALLPAPER="/usr/share/backgrounds/metta/metta-matrix-with-logo.png"
XFCONF_DIR="/etc/xdg/xfce4/xfconf/xfce-perchannel-xml"
SKEL_XFCONF="/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml"

install_file() {
  src="$1"
  dst="$2"
  [ -f "$src" ] || return 1
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
}

if [ ! -d /usr/share/themes/Metta-Dark ]; then
  echo "WARN: Metta-Dark theme missing — skipping Xfce defaults" >&2
  exit 0
fi

mkdir -p "$XFCONF_DIR" /etc/xdg/gtk-3.0 /etc/xdg/xfce4/panel "$SKEL_XFCONF" /etc/skel/.config/gtk-3.0

for f in xsettings.xml xfwm4.xml xfce4-desktop.xml; do
  install_file "$METTA_XFCE/$f" "$XFCONF_DIR/$f" || true
  install_file "$METTA_XFCE/$f" "$SKEL_XFCONF/$f" || true
done

install_file "$METTA_XFCE/gtk-3.0-settings.ini" /etc/xdg/gtk-3.0/settings.ini || true
install_file "$METTA_XFCE/gtk-3.0-settings.ini" /etc/skel/.config/gtk-3.0/settings.ini || true

if [ -f /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml ]; then
  install_file /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml \
    /etc/xdg/xfce4/panel/default.xml || true
fi

if [ -f /usr/lib/metta/xfce-live-setup.sh ]; then
  chmod 755 /usr/lib/metta/xfce-live-setup.sh 2>/dev/null || true
fi

if [ -f "$WALLPAPER" ]; then
  PROFILE="/usr/share/xfdesktop/xfdesktop.defaults.xfce4.xml"
  if [ -f "$PROFILE" ]; then
    sed -i "s|/usr/share/backgrounds/[^\"]*|$WALLPAPER|g" "$PROFILE" 2>/dev/null || true
  fi
fi

exit 0
