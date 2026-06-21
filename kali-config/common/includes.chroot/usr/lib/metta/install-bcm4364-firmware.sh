#!/bin/sh
# METTA OS — Apple Broadcom BCM4364 (brcmfmac4364b2-pcie) firmware installer.
# Source: apple-bcm-firmware Arch package (Sneed-Group).
set -eu

FW_URL="${METTA_BCM4364_FW_URL:-https://raw.githubusercontent.com/Sneed-Group/apple-broadcom-firmware-arch/main/apple-bcm-firmware-14.0-1-any.pkg.tar.zst}"
DEST_DIR="/lib/firmware/brcm"
PKG_NAME="apple-bcm-firmware-14.0-1-any.pkg.tar.zst"

BIN_DST="$DEST_DIR/brcmfmac4364b2-pcie.bin"
CLM_DST="$DEST_DIR/brcmfmac4364b2-pcie.clm_blob"
TXC_DST="$DEST_DIR/brcmfmac4364b2-pcie.txcap_blob"
TXT_DST="$DEST_DIR/brcmfmac4364b2-pcie.txt"

firmware_complete() {
    [ -f "$BIN_DST" ] && [ -f "$CLM_DST" ] && [ -f "$TXC_DST" ] && [ -f "$TXT_DST" ]
}

if firmware_complete; then
    echo "INFO: BCM4364 firmware already installed in $DEST_DIR"
    exit 0
fi

for cmd in zstd wget; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: missing required command: $cmd" >&2
        exit 1
    }
done

WORK=$(mktemp -d)
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

PKG="$WORK/$PKG_NAME"
echo "INFO: downloading Apple BCM4364 firmware..."
if ! wget -q -O "$PKG" "$FW_URL" 2>/dev/null; then
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$PKG" "$FW_URL" || {
            echo "ERROR: firmware download failed" >&2
            exit 1
        }
    else
        echo "ERROR: firmware download failed (wget/curl)" >&2
        exit 1
    fi
fi

echo "INFO: extracting firmware package..."
tar --use-compress-program=unzstd -xf "$PKG" -C "$WORK"

SRC="$WORK/usr/lib/firmware/brcm"
if [ ! -d "$SRC" ]; then
    echo "ERROR: extracted package missing usr/lib/firmware/brcm" >&2
    exit 1
fi

if ! ls "$SRC" | grep -q '4364b2'; then
    echo "ERROR: package does not contain BCM4364b2 firmware files" >&2
    exit 1
fi

BIN_SRC="$SRC/brcmfmac4364b2-pcie.apple,ekans.bin"
CLM_SRC="$SRC/brcmfmac4364b2-pcie.apple,ekans.clm_blob"
TXC_SRC="$SRC/brcmfmac4364b2-pcie.apple,ekans.txcap_blob"

for f in "$BIN_SRC" "$CLM_SRC" "$TXC_SRC"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: missing firmware file: $(basename "$f")" >&2
        exit 1
    fi
done

TXT_SRC="$SRC/brcmfmac4364b2-pcie.apple,ekans-HRPN-m-7.1.txt"
if [ ! -f "$TXT_SRC" ]; then
    TXT_SRC=$(ls "$SRC"/brcmfmac4364b2-pcie.apple,ekans-HRPN-m-*.txt 2>/dev/null | head -1)
fi
if [ -z "$TXT_SRC" ] || [ ! -f "$TXT_SRC" ]; then
    echo "ERROR: no ekans HRPN .txt calibration file found in firmware package" >&2
    exit 1
fi

mkdir -p "$DEST_DIR"
install -m 644 "$BIN_SRC" "$BIN_DST"
install -m 644 "$CLM_SRC" "$CLM_DST"
install -m 644 "$TXC_SRC" "$TXC_DST"
install -m 644 "$TXT_SRC" "$TXT_DST"

echo "INFO: installed BCM4364 firmware:"
ls -1 "$DEST_DIR"/brcmfmac4364b2-pcie.*

if command -v update-initramfs >/dev/null 2>&1; then
    echo "INFO: updating initramfs..."
    update-initramfs -u -k all 2>/dev/null || update-initramfs -u 2>/dev/null || true
fi

echo "INFO: BCM4364 firmware ready (reboot if Wi-Fi was already probed)"
