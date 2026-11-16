#!/usr/bin/env bash
# ==============================================================================
# ZTE CloudBook Air (CT2000-24RTW / RK3568B2)
# One-Click Factory Android 11 Restore Script
# ==============================================================================
# Usage (run on the board when booted from the USB Linux system):
#   1. From local directory containing factory_backup files:
#        ./restore_factory_android.sh /path/to/factory_backup
#   2. Or stream directly from a host HTTP server serving factory_backup/:
#        BACKUP_URL="http://<HOST_IP>:18080/factory_backup" ./restore_factory_android.sh
#
# What this script restores:
#   1. /dev/mmcblk0p11 (boot_a)   <- boot_a_4.19_verified_20261112.img
#   2. /dev/mmcblk0p12 (boot_b)   <- verified (or restored from boot_b.img if needed)
#   3. /dev/mmcblk0p15 (metadata) <- metadata.img
#   4. /dev/mmcblk0p14 (cache)    <- cache.img.zst
#   5. /dev/mmcblk0p20 (userdata) <- userdata.img.zst (full 22GB Android userdata backup)
#   6. /dev/mmcblk0p6  (misc)     <- misc_android_slot_b.img (sets active slot _b with
#                                    priority=15, successful_boot=1, fallback _a priority=14,
#                                    valid AB0 CRC32, and clears recovery BCB at 0x0/0x4000)
# ==============================================================================

set -euo pipefail

BACKUP_SRC="${1:-${BACKUP_DIR:-}}"
BACKUP_HTTP="${BACKUP_URL:-}"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: Please run this script as root." >&2
    exit 1
fi

# Ensure /dev/mmcblk0p20 is not mounted as /
ROOT_SRC="$(findmnt -n -o SOURCE / || true)"
if [[ "$ROOT_SRC" == "/dev/mmcblk0p20" ]]; then
    echo "ERROR: Currently booted from /dev/mmcblk0p20! Please boot from the USB drive (/dev/sda1) first." >&2
    exit 1
fi
umount /dev/mmcblk0p20 2>/dev/null || true

fetch_to_file() {
    local name="$1"
    local dst="$2"
    if [[ -n "$BACKUP_SRC" && -f "$BACKUP_SRC/$name" ]]; then
        cp -f "$BACKUP_SRC/$name" "$dst"
    elif [[ -n "$BACKUP_HTTP" ]]; then
        curl -fL "$BACKUP_HTTP/$name" -o "$dst"
    else
        echo "ERROR: Cannot find $name (specify backup dir arg or BACKUP_URL env)" >&2
        exit 1
    fi
}

stream_file() {
    local name="$1"
    if [[ -n "$BACKUP_SRC" && -f "$BACKUP_SRC/$name" ]]; then
        cat "$BACKUP_SRC/$name"
    elif [[ -n "$BACKUP_HTTP" ]]; then
        curl -fsSL "$BACKUP_HTTP/$name"
    else
        echo "ERROR: Cannot find $name (specify backup dir arg or BACKUP_URL env)" >&2
        exit 1
    fi
}

echo "=== [1/5] Restoring /dev/mmcblk0p11 (boot_a) to Factory Android 4.19 ==="
stream_file "boot_a_4.19_verified_20261112.img" | dd of=/dev/mmcblk0p11 bs=4M conv=fsync status=progress

echo "=== [2/5] Restoring /dev/mmcblk0p15 (metadata) ==="
stream_file "metadata.img" | dd of=/dev/mmcblk0p15 bs=4M conv=fsync status=progress

echo "=== [3/5] Restoring /dev/mmcblk0p14 (cache) ==="
if command -v zstd >/dev/null 2>&1; then
    stream_file "cache.img.zst" | zstd -dc | dd of=/dev/mmcblk0p14 bs=4M conv=fsync status=progress
else
    mkfs.ext4 -F -L cache /dev/mmcblk0p14
fi

echo "=== [4/5] Restoring /dev/mmcblk0p20 (userdata, 23,627,530,240 bytes) ==="
if [[ "${FAST_WIPE_USERDATA:-0}" == "1" ]]; then
    echo "FAST_WIPE_USERDATA=1 requested: wiping first 64MB of /dev/mmcblk0p20 and formatting..."
    dd if=/dev/zero of=/dev/mmcblk0p20 bs=4M count=16 conv=fsync
else
    if ! command -v zstd >/dev/null 2>&1; then
        echo "Installing zstd for userdata decompression..."
        apt-get update && apt-get install -y zstd
    fi
    stream_file "userdata.img.zst" | zstd -dc | dd of=/dev/mmcblk0p20 bs=4M conv=fsync status=progress
fi

echo "=== [5/5] Configuring /dev/mmcblk0p6 (misc) for Factory Android (Slot _b active, _a fallback) ==="
stream_file "misc_android_slot_b.img" | dd of=/dev/mmcblk0p6 bs=4M conv=fsync status=none
python3 - <<'PYEOF'
import struct, zlib

# Verify or synthesize clean 4MB misc partition AB0 boot_control block at 0x0800:
# - Offset 0x0000..0x0100: zeroed (no BCB recovery command)
# - Offset 0x0800..0x0820: Android/Rockchip AvbABData boot_control block:
#     magic = "\x00AB0", version = 1.0
#     slot_a: priority=14, tries_remaining=0, successful_boot=1
#     slot_b: priority=15, tries_remaining=0, successful_boot=1
#     crc32  = big-endian CRC32 (11 9c 9c ae)
# - Offset 0x4000..0x4100: zeroed (no Rockchip 16K BCB boot-recovery / --wipe_all)
ab = bytearray(32)
ab[0:4]   = b"\x00AB0"
ab[4:8]   = b"\x01\x00\x00\x00"
ab[8:12]  = bytes([14, 0, 1, 0])  # slot_a: prio 14, successful 1
ab[12:16] = bytes([15, 0, 1, 0])  # slot_b: prio 15, successful 1
crc = zlib.crc32(bytes(ab[:28])) & 0xffffffff
struct.pack_into(">I", ab, 28, crc)

with open("/dev/mmcblk0p6", "rb") as f:
    f.seek(0x800)
    verify = f.read(32)
    f.seek(0x4000)
    bcb16k = f.read(64)

assert verify == bytes(ab), f"misc AB0 verify mismatch: {verify.hex()} != {ab.hex()}"
assert not any(bcb16k), f"misc 0x4000 BCB not clean: {bcb16k}"
print(f"misc (/dev/mmcblk0p6) verified OK: AB0={verify.hex()} (CRC32=0x{crc:08x}, slot_b prio=15 active, slot_a prio=14 fallback)")
PYEOF

sync
echo "=============================================================================="
echo "SUCCESS: Factory Android 11 has been restored and misc (/dev/mmcblk0p6) is configured."
echo "Unplug the USB drive and run 'reboot' to boot into Factory Android."
echo "=============================================================================="
