#!/bin/sh
# METTA OS — disk installer engine (must run as root).
set -eu

LOG="${METTA_INSTALL_LOG:-/tmp/metta-install.log}"
TARGET="/target/metta-install"
ESP_PART=""
ROOT_PART=""
DISK=""

log() {
  echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"
}

die() {
  log "ERROR: $*"
  exit 1
}

require_root() {
  [ "$(id -u)" -eq 0 ] || die "Se requieren privilegios de root"
}

find_squashfs() {
  for path in \
    /run/live/medium/live/filesystem.squashfs \
    /lib/live/mount/medium/live/filesystem.squashfs \
    /run/live/medium/live/filesystem.sfs \
    /lib/live/mount/medium/live/filesystem.sfs
  do
    [ -f "$path" ] && { echo "$path"; return 0; }
  done
  return 1
}

list_disks_json() {
  lsblk -J -d -o NAME,SIZE,MODEL,TYPE,TRAN,RM,ROTA 2>/dev/null | \
    sed 's/"tran":"usb"/"metta_removable":true/g' || lsblk -d -o NAME,SIZE,MODEL
}

cmd_list_disks() {
  list_disks_json
}

cleanup_mounts() {
  umount "$TARGET/dev/pts" 2>/dev/null || true
  umount "$TARGET/dev" 2>/dev/null || true
  umount "$TARGET/proc" 2>/dev/null || true
  umount "$TARGET/sys" 2>/dev/null || true
  umount "$TARGET/boot/efi" 2>/dev/null || true
  umount "$TARGET" 2>/dev/null || true
  rmdir "$TARGET" 2>/dev/null || true
}

partition_disk() {
  disk="$1"
  log "Particionando $disk (GPT + ESP + root ext4)..."
  wipefs -a "$disk" >/dev/null 2>&1 || true
  parted -s "$disk" mklabel gpt
  parted -s "$disk" mkpart ESP fat32 1MiB 513MiB
  parted -s "$disk" set 1 esp on
  parted -s "$disk" mkpart root ext4 513MiB 100%
  partprobe "$disk" 2>/dev/null || true
  sleep 2
  case "$disk" in
    *nvme*|*mmcblk*)
      ESP_PART="${disk}p1"
      ROOT_PART="${disk}p2"
      ;;
    *)
      ESP_PART="${disk}1"
      ROOT_PART="${disk}2"
      ;;
  esac
  mkfs.vfat -F32 -n METTA-EFI "$ESP_PART"
  mkfs.ext4 -F -L METTA-ROOT "$ROOT_PART"
}

mount_target() {
  mkdir -p "$TARGET"
  mount "$ROOT_PART" "$TARGET"
  mkdir -p "$TARGET/boot/efi"
  mount "$ESP_PART" "$TARGET/boot/efi"
}

copy_live_system() {
  squashfs="$(find_squashfs)" || die "No se encontró filesystem.squashfs del live"
  log "Extrayendo sistema desde $squashfs ..."
  if command -v unsquashfs >/dev/null 2>&1; then
    unsquashfs -f -d "$TARGET" "$squashfs"
  else
    die "unsquashfs no está instalado"
  fi
}

setup_chroot() {
  mount --bind /dev "$TARGET/dev"
  mount -t proc proc "$TARGET/proc"
  mount -t sysfs sys "$TARGET/sys"
  mount --bind /dev/pts "$TARGET/dev/pts"
  if [ -d /sys/firmware/efi ]; then
    mkdir -p "$TARGET/sys/firmware/efi/efivars"
    mount -t efivarfs efivarfs "$TARGET/sys/firmware/efi/efivars" 2>/dev/null || true
  fi
}

write_fstab() {
  root_uuid="$(blkid -s UUID -o value "$ROOT_PART")"
  esp_uuid="$(blkid -s UUID -o value "$ESP_PART")"
  cat > "$TARGET/etc/fstab" << EOF
# METTA OS — generado por metta-installer
UUID=$root_uuid  /          ext4  errors=remount-ro  0  1
UUID=$esp_uuid   /boot/efi  vfat  umask=0077         0  1
EOF
}

configure_users() {
  hostname="$1"
  username="$2"
  password="$3"
  log "Configurando hostname=$hostname usuario=$username"
  echo "$hostname" > "$TARGET/etc/hostname"
  sed -i "s/^127.0.1.1.*/127.0.1.1\t$hostname/" "$TARGET/etc/hosts" 2>/dev/null || \
    echo "127.0.1.1\t$hostname" >> "$TARGET/etc/hosts"

  if ! chroot "$TARGET" id "$username" >/dev/null 2>&1; then
    chroot "$TARGET" useradd -m -s /bin/zsh -G sudo,audio,video,plugdev,netdev "$username"
  fi
  echo "$username:$password" | chroot "$TARGET" chpasswd
}

install_bootloader() {
  log "Instalando GRUB..."
  if [ -d /sys/firmware/efi ]; then
    chroot "$TARGET" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=METTA --recheck
  else
    chroot "$TARGET" grub-install "$DISK"
  fi
  chroot "$TARGET" update-grub 2>/dev/null || true
}

purge_live_packages() {
  chroot "$TARGET" apt-get remove -y --purge live-boot live-config live-config-systemd 2>/dev/null || true
  chroot "$TARGET" apt-get autoremove -y 2>/dev/null || true
}

cmd_install() {
  disk="$1"
  username="$2"
  password_file="$3"
  hostname="${4:-mettaos}"

  require_root
  case "$disk" in
    /dev/*) ;;
    *) die "Disco inválido: $disk" ;;
  esac
  case "$username" in
    ""|*[!a-z0-9_-]*) die "Usuario inválido" ;;
  esac
  case "$hostname" in
    ""|*[!A-Za-z0-9-]*) die "Hostname inválido" ;;
  esac
  [ -f "$password_file" ] || die "No se recibió la contraseña"
  password="$(cat "$password_file")"
  rm -f "$password_file"
  case "$password" in
    *'
'*|*:*|"") die "Contraseña inválida" ;;
  esac
  DISK="$disk"
  : > "$LOG"

  [ -b "$disk" ] || die "Disco inválido: $disk"
  log "=== METTA OS Installer ==="
  log "Disco: $disk | Usuario: $username | Host: $hostname"

  cleanup_mounts
  trap cleanup_mounts EXIT INT TERM

  partition_disk "$disk"
  mount_target
  copy_live_system
  write_fstab
  setup_chroot
  configure_users "$hostname" "$username" "$password"
  purge_live_packages
  chroot "$TARGET" update-initramfs -u -k all 2>/dev/null || true
  /usr/lib/metta/metta-system-postinstall.sh "$TARGET"
  install_bootloader

  sync
  log "=== Instalación completada. Reinicia para usar METTA OS. ==="
  trap - EXIT INT TERM
  cleanup_mounts
}

usage() {
  cat <<EOF
METTA OS Installer Engine
  list-disks
  install <disk> <username> <password-file> [hostname]
EOF
}

case "${1:-}" in
  list-disks) cmd_list_disks ;;
  install)
    [ "$#" -ge 4 ] || { usage; exit 1; }
    cmd_install "$2" "$3" "$4" "${5:-mettaos}"
    ;;
  *) usage; exit 1 ;;
esac
