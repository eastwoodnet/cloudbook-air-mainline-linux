#!/usr/bin/env python3
"""
Safe A/B Slot Switcher for ZTE CloudBook Air CT2000-24RTW (RK3568)
Modifies AvbABData at offset 0x800 of misc.img with valid big-endian CRC32.

Usage:
  1. Test Linux on Slot A (boot_a) with automatic 3-try fallback to Android on Slot B (boot_b):
     python3 switch_ab_slot.py test_slot_a misc_try_a.img
     adb push misc_try_a.img /data/local/tmp/
     adb shell "dd if=/data/local/tmp/misc_try_a.img of=/dev/block/by-name/misc && sync"

  2. Restore Android on Slot B (boot_b) as default:
     python3 switch_ab_slot.py restore_slot_b misc_slot_b.img
"""

import sys
import struct
import binascii
from pathlib import Path

BASE_MISC = Path(__file__).parent / "factory_backup" / "misc.img"

def build_ab_data(s0_prio, s0_tries, s0_succ, s1_prio, s1_tries, s1_succ):
    # struct AvbABData (32 bytes total, CRC32 big-endian at bytes 28..32)
    body = struct.pack(
        "<4sBB2x BBBx BBBx 12x",
        b"\x00AB0", 1, 0,
        s0_prio, s0_tries, s0_succ,
        s1_prio, s1_tries, s1_succ,
    )
    crc = binascii.crc32(body) & 0xFFFFFFFF
    return body + struct.pack(">I", crc)

def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("test_slot_a", "commit_slot_a", "restore_slot_b"):
        print("Usage: python3 switch_ab_slot.py [test_slot_a | commit_slot_a | restore_slot_b] <output_misc.img>")
        sys.exit(1)

    mode = sys.argv[1]
    out_path = Path(sys.argv[2])

    if BASE_MISC.exists():
        data = bytearray(BASE_MISC.read_bytes())
    else:
        data = bytearray(4 * 1024 * 1024)

    # Clear any BCB command at 0x0 and 0x4000 so U-Boot boots normal flow
    data[0x0000:0x0040] = b"\x00" * 0x40
    data[0x4000:0x4040] = b"\x00" * 0x40

    if mode == "test_slot_a":
        # Slot A (boot_a, Linux): prio=15, tries=3, successful=0
        # Slot B (boot_b, Android): prio=14, tries=0, successful=1 (Auto-fallback target!)
        ab = build_ab_data(15, 3, 0, 14, 0, 1)
        desc = "Slot A (test, 3 tries with auto-fallback to Slot B Android)"
    elif mode == "commit_slot_a":
        # Slot A permanent, Slot B backup
        ab = build_ab_data(15, 0, 1, 14, 0, 1)
        desc = "Slot A (permanent) / Slot B (backup)"
    else:
        # Slot B (Android) permanent
        ab = build_ab_data(14, 0, 1, 15, 0, 1)
        desc = "Slot B (Android default)"

    data[0x800:0x820] = ab
    out_path.write_bytes(data)
    print(f"[OK] Wrote {out_path} ({len(data)} bytes) -> {desc}")

if __name__ == "__main__":
    main()
