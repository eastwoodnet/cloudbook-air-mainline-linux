#!/usr/bin/env python3
"""Extract the Rockchip RSCE second-stage image (resource.img) from a factory Android boot.img."""

import argparse
import struct
from pathlib import Path


def extract_resource(boot_path: Path, out_path: Path) -> None:
    data = boot_path.read_bytes()
    magic, k_sz, _k_addr, r_sz, _r_addr, s_sz, _s_addr, _tags, pg, _ver, _os = struct.unpack_from(
        "<8s10I", data, 0
    )
    if magic != b"ANDROID!":
        raise ValueError(f"{boot_path} is not an Android boot image (magic={magic!r})")
    if s_sz == 0:
        raise ValueError(f"{boot_path} has second_size == 0 (no embedded resource.img)")

    def align_page(n: int) -> int:
        return (n + pg - 1) & ~(pg - 1)

    sec_off = pg + align_page(k_sz) + align_page(r_sz)
    sec_bytes = data[sec_off : sec_off + s_sz]
    if sec_bytes[:4] != b"RSCE":
        raise ValueError(f"Expected RSCE header at offset {sec_off}, got {sec_bytes[:4]!r}")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_bytes(sec_bytes)
    print(f"[OK] Extracted {out_path} ({len(sec_bytes)} bytes) from {boot_path}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("boot_img", type=Path, help="Input factory boot_b.img (or boot_a.img)")
    ap.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path("artifacts/extracted_resource.img"),
        help="Output resource.img path (default: artifacts/extracted_resource.img)",
    )
    args = ap.parse_args()
    extract_resource(args.boot_img, args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
