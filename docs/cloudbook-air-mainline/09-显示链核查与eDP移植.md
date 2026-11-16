# CloudBook Air 6.12 显示链核查与 eDP 移植（v9/v10）

> **日期**：2026-11-13  
> **状态**：**进行中，尚未完成屏幕验证**。v9 内核已构建并静态核查通过；首次 kexec 因 DTB 缺少 `/memory` 节点在 `paging_init` panic，设备当前处于 halt 状态，需要一次目标机物理断电重启。  
> **原则**：不写 eMMC；保留 `boot_b`/`uboot_a/b`/`trust_a/b`/前 8 MiB；kexec 只做内存启动验证。  
> **当前设备**：Linux 6.12.117-cloudbook（v8，boot_a）/ USB `ROOTFS` / 串口 `ttyS2`。

---

## 1 本轮目标

在不写 eMMC 的前提下，验证 6.12 内屏显示链：

1. VOP2 控制器与 IOMMU；
2. eDP 控制器 `edp@fe0c0000`；
3. eDP PHY `edp-phy@fdcb0000`；
4. BOE NV140WUM-N44 面板（`edp-panel`）与 EDID；
5. PWM8 背光 + 面板使能/电源 GPIO；
6. DRM/KMS 输出状态与 1920×1200 mode。

---

## 2 v9 内核与 DTB 改动

### 2.1 配置改为全部内置

v8 的 DTB 中 `vop`、`vop_mmu`、`pwm8` 为 `disabled`，且设备上没有 6.12 模块目录，显示驱动不能以模块方式加载。v9 将显示链改为内置：

```text
CONFIG_DRM=y
CONFIG_DRM_KMS_HELPER=y
CONFIG_DRM_DISPLAY_HELPER=y
CONFIG_DRM_DISPLAY_DP_AUX_BUS=y
CONFIG_DRM_DISPLAY_DP_HELPER=y
CONFIG_DRM_GEM_DMA_HELPER=y
CONFIG_DRM_ROCKCHIP=y
CONFIG_ROCKCHIP_ANALOGIX_DP=y
CONFIG_PHY_ROCKCHIP_NANENG_EDP=y
CONFIG_DRM_PANEL_EDP=y
CONFIG_DRM_PANEL_SIMPLE=y
CONFIG_BACKLIGHT_CLASS_DEVICE=y
CONFIG_BACKLIGHT_PWM=y
CONFIG_PWM=y
CONFIG_PWM_ROCKCHIP=y
```

`build_kernel_612.sh` 已同步为上述配置。

### 2.2 v9 DTB 静态核查

反编译 `rk3568-v9.dtb` 确认：

| 节点 | 状态 / 兼容性 |
|---|---|
| `vop@fe040000` | `okay`，`rockchip,rk3568-vop` |
| `iommu@fe043e00` | `okay` |
| `edp@fe0c0000` | `okay`，`rockchip,rk3568-edp` |
| `edp-phy@fdcb0000` | `okay`，`rockchip,rk3568-edp-phy` |
| `pwm@fe6f0000` | `okay`，`rockchip,rk3568-pwm` |
| `/backlight` | `pwm-backlight`，PWM8 + `GPIO2_D3` 使能 |
| `/edp@fe0c0000/aux-bus/panel` | `edp-panel`，BOE EDID、`GPIO2_D4` 使能、`vcc3v3_lcd_edp` |
| `display-subsystem` | `ports = <&vop_out>` |

源文件：`mainline-6.12/rk3568-ecloudbook-air-24rtw-v9-edp.dts`  
内核树副本：`linux-6.12/arch/arm64/boot/dts/rockchip/rk3568-ecloudbook-air-24rtw.dts`

6.12 源码中已确认存在 RK3568 eDP 支持：

- `drivers/gpu/drm/rockchip/analogix_dp-rockchip.c` 有 `rockchip,rk3568-edp`；
- `drivers/phy/rockchip/phy-rockchip-naneng-edp.c` 有 `rockchip,rk3568-edp-phy`；
- 本机 PHY 补丁包含 `zte,edp-v12-v13` 的 V12/V13 BOE N44 override。

---

## 3 首次 kexec 尝试与失败原因

### 3.1 已执行

在 v8 用户态通过 HTTP 下载 `Image`、`rk3568-v9.dtb`、`initramfs.gz`，校验 SHA-256 后执行：

```bash
kexec -c -l /tmp/v9/Image \
  --dtb=/tmp/v9/rk3568-v9.dtb \
  --initrd=/tmp/v9/initramfs.gz \
  --command-line="$CMDLINE"
```

装载返回 `KEXEC_LOAD_RC=0`，`/sys/kernel/kexec_loaded=1`，随后执行 `kexec -e`。

### 3.2 结果

新内核启动到 `setup_arch` 时 panic：

```text
[    0.000000] Linux version 6.12.117-cloudbook ... #6
[    0.000000] Machine model: China Mobile (ZTE) CloudBook Air CT2000-24RTW
[    0.000000] Kernel panic - not syncing: Failed to allocate page table page
[    0.000000]  create_kpti_ng_temp_pgd+0x1f8/0xc30
[    0.000000]  __map_memblock+0x6c/0x8c
[    0.000000]  paging_init+0x10/0x28
[    0.000000] Rebooting in 10 seconds..
[    0.000000] Reboot failed -- System halted
```

完整串口记录：`logs/uart-kexec-v9-panic-20261113.log`

### 3.3 根因

`early_pgtable_alloc()` 通过 `memblock_phys_alloc_range()` 分配页表，失败说明 **memblock 中没有可用 RAM**。

v9 DTB 是给 U-Boot 启动用的板级 DTB，**没有 `/memory` 节点**；正常冷启动时由 U-Boot 根据 DRAM 容量注入 `/memory`。kexec 绕过 U-Boot，直接使用我们传入的 DTB，因此新内核看到 0 字节 RAM，在 `paging_init` 分配 KPTI 临时页表时 panic。

panic 发生在 PSCI 初始化之前，`Rebooting in 10 seconds` 无法真正复位，最终 `System halted`。软件侧已无法自行恢复。

---

## 4 v10 kexec 专用 DTB

从原厂 4.19 设备树 `/memory/reg` 提取内存布局，总和与 v8 启动日志 `Memory: 4175868K` 完全一致：

| base | size | 说明 |
|---|---|---|
| `0x0_00200000` | `0x0_08200000` | 2 MiB – 132 MiB |
| `0x0_09400000` | `0x0_e6c00000` | 148 MiB – 3840 MiB |
| `0x1_f0000000` | `0x0_10000000` | 7936 MiB – 8192 MiB |

v10 在 v9 DTB 基础上增加：

```dts
memory {
    device_type = "memory";
    reg = <0x0 0x200000 0x0 0x8200000>,
          <0x0 0x9400000 0x0 0xe6c00000>,
          <0x1 0xf0000000 0x0 0x10000000>;
};
```

产物：

- `build/6.12-v10-kexec/rk3568-v10-kexec.dtb`
- SHA-256：`04ce25803cdb79295ad1069c56c21f1b49ca2c13ac8fddb63c9afaf18d2cd2aa`

该 DTB 仅用于 kexec，不替换 U-Boot 正常启动用的板级 DTB。

---

## 5 当前设备状态与恢复步骤

**当前**：串口停在 `System halted`，需要目标机物理断电重启一次。

恢复后预期：

1. U-Boot 从 `boot_a` 启动 v8 6.12（`misc` 中 Slot A 仍剩 1 次试启动）；
2. 网络恢复 `<DEVICE_IP>`，USB `ROOTFS` 挂载；
3. 重新下载 v10 DTB 与 v9 Image/initramfs；
4. 用 v10 DTB 重新 `kexec -c -l`，再 `kexec -e`；
5. 串口核查 DRM/eDP/panel/backlight 链路。

> 若 v8 也未能启动，U-Boot 会回退 Slot B 原厂 Android；这是保留的回退路径。

---

## 6 恢复后的验收标准

软件层面必须全部满足：

```text
uname -r                         → 6.12.117-cloudbook
/proc/cmdline                    → 包含本次 kexec 的 cmdline
/sys/firmware/devicetree/base/model → CloudBook Air CT2000-24RTW
ls /sys/class/drm                → card0 / card0-eDP-1
cat /sys/class/drm/card*-eDP-1/status → connected
cat /sys/class/drm/card*-eDP-1/modes  → 1920x1200
ls /sys/class/backlight          → backlight
dmesg | grep -Ei 'vop|edp|analogix|panel|backlight|pwm|drm|phy|iommu'
```

串口日志中不得出现：

- eDP link training 失败；
- PHY PLL lock 失败；
- panel prepare/enable 失败；
- `rockchip-drm` probe defer；
- VOP2/IOMMU 超时。

若以上通过，可认定 **DRM/eDP/panel/backlight 软件链路成功**；由于用户无法现场看屏，最终报告必须区分“串口确认链路成功”与“肉眼确认物理屏幕点亮”。

---

## 7 产物与哈希

| 文件 | SHA-256 |
|---|---|
| `build/6.12-v9/Image` | `9ff5cbc4da0ca6e87661a6cae6c272ae02a98baea7b1b7ecb72126ab9e29578c` |
| `build/6.12-v9/rk3568-v9.dtb` | `c8e59b336c0b6b655f7aeb287ba4229d7e3f48a0547f2de88e9429ef0838bdda` |
| `build/6.12-v9/initramfs-cloudbook-v8.gz` | `b7dbea6e907d58cacaaf25bbc126e135827e8f611b070c2114e73d5e81a1ab8f` |
| `build/6.12-v9/config-6.12.117-cloudbook` | `e6224d6e42a2b20683da503718c77289c6210e98fd61bcefb966c16e6f0a91e5` |
| `build/6.12-v10-kexec/rk3568-v10-kexec.dtb` | `04ce25803cdb79295ad1069c56c21f1b49ca2c13ac8fddb63c9afaf18d2cd2aa` |

---

## 8 约束

- 不写 `boot_b`、`uboot_a/b`、`trust_a/b`、前 8 MiB `idbloader`；
- 不覆盖 `build/6.12-v8/` 成功证据；
- 不操作 `<UNRELATED_DEVICE_IP>:5555`；
- 不 `git commit`、不建分支；
- kexec 失败时保留串口最后日志，优先回退到 v8 / Slot B。
