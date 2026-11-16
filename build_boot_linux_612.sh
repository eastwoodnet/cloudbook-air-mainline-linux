#!/usr/bin/env bash
# Pack the locally built 6.12 candidate. This script never flashes or reboots.
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
OUT_DIR="$ROOT_DIR/kernel_build/out-6.12"
NAME=rk3568-ecloudbook-air-24rtw
# Default to the v8 rescue initramfs and a rebuild-only output path so the
# already-verified v8 evidence image is never overwritten by accident.
RAMDISK=${RAMDISK:-$ROOT_DIR/artifacts/initramfs-6.12.117-cloudbook-emmc.img}
RESOURCE_TEMPLATE=${RESOURCE_TEMPLATE:-$ROOT_DIR/artifacts/extracted_resource.img}
OUTPUT=${1:-$ROOT_DIR/artifacts/boot_linux_612_v29_emmc_rebuild.img}
CMDLINE=${CMDLINE:-'console=tty0 console=ttyS2,115200n8 root=LABEL=EMMC_ROOTFS rootfstype=ext4 rootwait rw net.ifnames=0 clk_ignore_unused pd_ignore_unused cpuidle.off=1 systemd.show_status=1 systemd.default_timeout_start_sec=15s loglevel=7 no_console_suspend'}

python3 "$ROOT_DIR/pack_boot_linux.py" \
    --kernel "$OUT_DIR/arch/arm64/boot/Image" \
    --ramdisk "$RAMDISK" \
    --dtb "$OUT_DIR/arch/arm64/boot/dts/rockchip/$NAME.dtb" \
    --resource-template "$RESOURCE_TEMPLATE" \
    --cmdline "$CMDLINE" \
    --output "$OUTPUT"

fdtget -p "$OUT_DIR/arch/arm64/boot/dts/rockchip/$NAME.dtb" /__symbols__ >/dev/null
fdtget -t s "$OUT_DIR/arch/arm64/boot/dts/rockchip/$NAME.dtb" /__symbols__ chosen >/dev/null
fdtget -t s "$OUT_DIR/arch/arm64/boot/dts/rockchip/$NAME.dtb" /__symbols__ reboot_mode >/dev/null
[[ $(stat -c %s "$OUTPUT") -le 167772160 ]]
sha256sum "$OUTPUT"
