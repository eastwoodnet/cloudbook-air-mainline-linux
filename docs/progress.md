# ZTE CloudBook Air 14" (CT2000-24RTW) 适配进度

> **依据规程**：[`rk-linux-bringup-skill`](.agents/skills/rk-linux-bringup-skill/SKILL.md)  
> **状态索引**：当前位置与阶段完成度状态机。  
> **最后更新**：2026-11-16  

---

## 1 当前位置

**主线 Linux 6.12 LTS 全量移植与内置 eMMC 迁移已达成日常可用状态**：实机运行 **`6.12.117-cloudbook`** + **`rk3568-ecloudbook-air-24rtw-v29-emmc-rootfs.dts`**（`boot_a`，`/dev/mmcblk0p11`），根文件系统已迁移至内置 32GB eMMC `/dev/mmcblk0p20`（`LABEL=EMMC_ROOTFS`，Armbian Debian 13 Trixie），`boot_b` 原厂 Android 11 完整保留。桌面为 **LightDM + i3wm + Mali-G52 Panfrost 硬件加速**；已完成 **MT7663S SDIO Wi-Fi + 蓝牙与 NetworkManager 兼容修复**（`0011` 补丁屏蔽 P2P/ROC/sched_scan）、**南芯 SC2021 PD + TI BQ25700/BQ25703A 充电驱动**（`0008` 补丁）、**霍尔盒盖开关与 USB2 PHY 休眠时钟修复**（`v27`/`v28`），并验证 **Hantro VPU (`v4l2codecs` + `xvimagesink`) H.264 1080p 硬件解码**。

---

## 2 阶段完成度

| 阶段 | 小阶段 | 状态 | 备注 |
|---|---|---|---|
| P0 | P0-1 问诊与 board-profile | ✅ | [board-profile.md](board-profile.md) 定稿 |
| P0 | P0-2 成功定义与不做清单 | ✅ | 明确安全红线与回退预案 |
| P0 | **G0 准入门槛** | ✅ | A/B 槽 3 次回退验证通过 |
| P1 | P1-1 取证 | ✅ | DTB、寄存器、GPIO、符号表全量逆向取证 |
| P1 | P1-2 备份与校验 | ✅ | 完整 eMMC 分区冷备份 + SHA-256 固化 |
| P1 | **G1 取证门槛** | ✅ | 事实源完整闭环 |
| P1.5| 在役机 4.19 基线固化 | ✅ | 内屏/键盘/触控板/音频/摄像头/睡眠全通 |
| P2 | P2-1 串口全链路 | ✅ | `UART2` 115200 8N1 双向畅通 |
| P2 | P2-2 画面通道 | ✅ | Xorg 稳定显示，内屏 1920×1200@60Hz |
| P2 | **G2 观测门槛** | ✅ | 串口与画面双通道就绪 |
| P3 | P3-1~3 6.12 最小点亮 | ✅ | `v8` 越过早期复位，挂载 USB Rootfs 与串口成功 |
| P3 | **G3 点亮门槛** | ✅ | PMIC、eMMC、USB、RTC 均通过 |
| P4 | P4-1 eDP 显示链 | ✅ | `0009`+`0010` 补丁 + VPLL `659 MHz` 点亮 BOE NV140WUM-N44 (`1920x1200@60Hz`) |
| P4 | P4-2~6 全外设集成 | ✅ | 触控板、Panfrost GPU、HDMI、RK809/PDM 音频、SBS+SC2021+BQ25700、TSADC/SARADC、MT7663S Wi-Fi/BT、Hantro VPU H.264 硬解全部就绪 |
| P5 | 固化与内置 eMMC 迁移 | ✅ | `v29` 迁移 `/dev/mmcblk0p20` (`EMMC_ROOTFS`)，LightDM+i3wm，一键恢复脚本留存；仓库整理与开源文档归档完成 |
| P6 | 主线化与上游化 | ⬜ | 可选后续阶段（整理 DTS/驱动提交上游或 6.18+ 迁移） |

---

## 3 会话与文档索引

| 文档 / 日志 | 阶段 | 日期 | 主题 | 关键结论 |
|---|---|---|---|---|
| [`02-方案设计.md`](docs/cloudbook-air-mainline/02-方案设计.md) | P0 | 2026-11-10 | 主线 Linux 移植与安全架构设计 | 确定保留原厂签名 U-Boot，A/B 槽回退，U 盘 Rootfs |
| [`03-4.19基线验证摘要.md`](docs/cloudbook-air-mainline/03-4.19基线验证摘要.md) | P1.5 | 2026-11-11 | 4.19 显示与外设真机验证 | eDP 1920×1200、键盘、触控板、RK809 音频全通 |
| [`04-基线固化与外设验证.md`](docs/cloudbook-air-mainline/04-基线固化与外设验证.md) | P1.5 | 2026-11-12 | 4.19 基线固化与桌面自启动 | 摄像头、HDMI、电池采样、睡眠唤醒验证通过 |
| [`05-6.12最小启动构建.md`](docs/cloudbook-air-mainline/05-6.12最小启动构建.md) | P3 | 2026-11-12 | 6.12.117 构建与 v1~v8 测试复盘 | 定位 SDIO 卡死、unused clocks/genpd；v8 真机点亮并固化 |
| [`06-4.19与6.12内核差异及外设映射分析.md`](docs/cloudbook-air-mainline/06-4.19与6.12内核差异及外设映射分析.md) | P3 | 2026-11-12 | 4.19 vs 6.12 深度内核对账与故障假设 | 保留 v4 断电分析；DVFS 欠压根因已被 v7 推翻，G3 极简方案经 v8 验证 |
| [`07-6.12点亮成功与v8证据.md`](docs/cloudbook-air-mainline/07-6.12点亮成功与v8证据.md) | P3 | 2026-11-12 | v8 真机启动、运行态取证与产物固化 | 6.12.117 进入 Armbian；USB Rootfs、eMMC、USB、RTC 正常 |
| [`08-P4计划与根因验证.md`](docs/cloudbook-air-mainline/08-P4计划与根因验证.md) | P3→P4 | 2026-11-12 | P4 外设计划、刷写 SOP 与 4.15 秒复位对照实验 | 草案待确认：两阶段确认、单变量对照、显示链 PHY 风险 |
| [`09-显示链核查与eDP移植.md`](docs/cloudbook-air-mainline/09-显示链核查与eDP移植.md) | P4 | 2026-11-13 | 显示链全内置、v9 DTB、kexec panic 根因与 v10 kexec DTB | 缺 `/memory` 导致 kexec panic；v10 已补齐内存布局，待重启后复测 |

---

## 4 已知缺陷与排障清单

| # | 项 | 状态 | 说明 |
|---|---|---|---|
| 1 | 6.12 SDIO Wi-Fi 阻塞 | 已于 `v23` 解决 | 原误加 Amlogic `zte,sdio-fixed-1-8v` 跳过 `CMD11`；经 4.19 反汇编取证并删除该属性后，SDR104 tuning `phase 212` (`148.5 MHz` / `1.80 V`) 通过，`mt7663s` + `btmtksdio` 双通 |
| 2 | 6.12 约 4.2 秒整机复位 | v8 已越过 | 原“DVFS 欠压”结论被 v7 实测推翻；`v8`~`v23` 均稳定启动到用户态，待 P4 验收后补 `GPIO0_A0` 单变量因果确认 |
| 3 | 6.12 DRM 模块化导致电源域切断 | 假设，待验证 | P3 阶段禁用 VOP2/HDMI/eDP 节点；P4 已通过全内置显示配置点亮 `eDP-1` |
| 4 | 硬件看门狗 `wdt` 与 U-Boot 交接 | v8 已取证 | v8 DTB 中 `&wdt` 仍为 `okay`；早期 `cr=0x8`（使能位 0），probe 注册 `timeout=44`；`CONFIG_WATCHDOG_SYSFS` 未开启。不能证明它是 4.2 秒复位根因 |
| 5 | 方案 A `misc` 每次重启耗 2 次 try | 已实证 | SPL 将 `tries=3→2`，随后 U-Boot `ab_select_slot` 再减 `2→1`；因此重锚 `tries=3` 仅支持 1 次重启不触发回退 Slot B，现已重锚为 `tries=3` |
