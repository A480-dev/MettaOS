#!/bin/sh
# Apply METTA OS wallpaper and theme on every connected monitor (QEMU, hardware, etc.).

WALLPAPER="/usr/share/backgrounds/metta/metta-matrix-with-logo.png"
[ -f "$WALLPAPER" ] || WALLPAPER="/usr/share/backgrounds/metta/metta-matrix-default.png"
[ -f "$WALLPAPER" ] || exit 0

export DISPLAY="${DISPLAY:-:0}"

# Wait for xfconfd (session may start before the daemon is ready)
wait=0
while [ "$wait" -lt 30 ]; do
  if xfconf-query -c xsettings -p /Net/ThemeName >/dev/null 2>&1; then
    break
  fi
  sleep 1
  wait=$((wait + 1))
done

set_prop() {
  channel="$1"
  prop="$2"
  type="$3"
  value="$4"
  xfconf-query -c "$channel" -p "$prop" -n -t "$type" -s "$value" 2>/dev/null || \
    xfconf-query -c "$channel" -p "$prop" -s "$value" 2>/dev/null || true
}

apply_wallpaper_monitor() {
  mon="$1"
  set_prop xfce4-desktop "/backdrop/screen0/monitor${mon}/image-path" string "$WALLPAPER"
  set_prop xfce4-desktop "/backdrop/screen0/monitor${mon}/image-style" int 5
  set_prop xfce4-desktop "/backdrop/screen0/monitor${mon}/image-show" bool true
  ws=0
  while [ "$ws" -lt 4 ]; do
    base="/backdrop/screen0/monitor${mon}/workspace${ws}"
    set_prop xfce4-desktop "${base}/last-image" string "$WALLPAPER"
    set_prop xfce4-desktop "${base}/image-style" int 5
    set_prop xfce4-desktop "${base}/color-style" int 0
    ws=$((ws + 1))
  done
}

apply_theme() {
  set_prop xfwm4 /general/theme string Metta-Dark
  set_prop xsettings /Net/ThemeName string Metta-Dark
  set_prop xsettings /Net/IconThemeName string Papirus-Dark
  set_prop xsettings /Net/FontName string "Inter 10"
}

apply_theme

# Generic fallbacks used by older xfconf layouts
for mon in monitor0 monitor1 monitor2 monitor3 monitor4; do
  apply_wallpaper_monitor "$mon"
done

if command -v xrandr >/dev/null 2>&1; then
  for mon in $(xrandr --query | awk '/ connected/{print $1}'); do
    apply_wallpaper_monitor "$mon"
    # Xfce sometimes drops the hyphen in monitor names (Virtual-1 → Virtual1)
    case "$mon" in
      *-*)
        alt="${mon//-/}"
        apply_wallpaper_monitor "$alt"
        ;;
    esac
  done
fi

exit 0
