# CloudBook Air Linux 6.12 最小启动候选

## 目标

第一阶段只要求 UART 可诊断、内核挂载 USB `ROOTFS`、进入 Armbian 控制台，并具备基础输入和 USB 网络条件。eDP、音频、摄像头、PD 和 Wi-Fi 不作为首次启动的验收前提。

## 源码与输出

- 源码：`linux-6.12`，版本 `6.12.117`。
- 板级 DTS：`mainline-6.12/rk3568-ecloudbook-air-24rtw.dts`。
- 独立构建目录：`kernel_build/out-6.12`，不覆盖 6.18 的 `kernel_build/out`。
- 构建入口：工作区根目录 `build_kernel_612.sh`。
- 构建日志：`logs/build-6.12-minimal-20261112.log`。

首版配置把 UART、EXT4、USB 存储、xHCI/EHCI/OHCI、eMMC、I2C、RK8xx PMIC、USB 输入和 RTL8152 网络支持内置到内核，避免挂载 Rootfs 前依赖模块目录。已保存并应用 `patches/0001-r8152-add-sr9900-id.patch`，仅为现有 CoreChips SR9900（0fe6:9900）添加 r8152 设备 ID。该补丁有参考真机测试，但在本机 6.12 候选中仍需重新验证；首测仍建议准备 AX88179 或 RTL8153 网卡作为备选。

## 构建

```bash
./build_kernel_612.sh
```

该命令只读取源码并写本地构建目录，不连接或刷写设备。重新运行会保留并增量使用 `kernel_build/out-6.12/.config`；需要完全重建时，应另行备份后清理该独立输出目录。

## 验收边界

首版只构建 Image 和 DTB，不构建完整模块包；启动所需的存储、串口、USB 和输入支持均已内置。后续外设阶段再按实际驱动选择性构建和安装模块，避免通用 defconfig 产生大量无关模块。

生成 Image、DTB 和 boot.img 不等于真机启动成功。候选镜像必须先检查：

1. DTB 包含 `__symbols__`、`chosen` 和 `reboot_mode`；
2. boot cmdline 使用 `console=ttyS2,115200n8` 和 `root=LABEL=ROOTFS`；
3. 镜像小于 160 MiB 的 `boot_a` 分区；
4. 本地 SHA-256 清单完整；
5. UART 可用、Android B 保留，另行确认后才允许写入 `boot_a` 和重启。
