# CONTEXT —— LinuxforPad / pad8pro-kernel-build

> 本文件只放术语表，不放实现细节、不放决策过程。决策见 `docs/adr/`，
> 进度与排障见 `notes/BUILD-STATUS.md`。

## 设备与硬件

**piano**
Xiaomi Pad 8 Pro 的设备代号。上游设备树文件 `arch/arm64/boot/dts/qcom/sm8750-xiaomi-piano.dts`，
根节点 `compatible = "xiaomi,piano", "qcom,sm8750"`。本项目的唯一目标设备。

**SM8750 / sun**
Qualcomm SoC，piano 所用平台。内核里平台相关代码由 sm8750 平台代码无条件提供。

**NT36532 面板**
piano 的 3200x2136 双 DSI DSC 屏幕，Novatek NT36532 DDIC + BOE 面板。
Kconfig 符号 `CONFIG_DRM_PANEL_NOVATEK_NT36532`。**没有它就是黑屏。**

**Nanosic 803 MCU**
磁吸键盘 + Precision Touchpad 的控制器，走 I2C，Kconfig 符号 `CONFIG_HID_NANOSIC`。
需要固件 `nanosic/MCU_Upgrade.bin`。

## 配置

**universal_defconfig**
上游作者维护的基线内核配置（约 8459 行），采用 **allnoconfig 语义**：
没写到的选项一律为 `n`。因此它不含 piano 的显示/键盘/充电驱动。

**必需驱动片段（required fragment）**
`configs/pad8pro-required.config`。追加在 `universal_defconfig` 产生的 `.config`
之后、再跑 `olddefconfig`，用于补齐 defconfig 遗漏的板级驱动。
**不含它 = 黑屏 + 键盘不可用。**

**config_only 模式**
workflow_dispatch 的开关。只跑到 配置 → dtb → 驱动审计，不编译，
约 8 分钟。用于快速验证配置改动，避免烧 3 小时才知道断言写错了。

## 产物

**Image**
ARM64 内核镜像，构建产物是**未压缩**的裸 Image。
`CONFIG_KERNEL_ZSTD=y` 是内核**内置解压算法**的选择，
**不等于** Image 被 ZSTD 压缩了——别据此推断 boot header 版本。
打 boot 镜像时另行 `gzip -n -9` 重压，因此 header 用 **v2**，不是 v4（ADR-0001）。

**dtb**
设备树二进制。本项目只关心 `sm8750-xiaomi-piano.dtb`。

**modules**
`.ko` 集合。以 `INSTALL_MOD_STRIP=1` 安装，strip 后约 104 MB、8743 个。

**boot 镜像（boot.img）**
Android boot image。**header v2**、`--pagesize 4096`（必须与真机
`ro.boot.hardware.cpu.pagesize` 一致）。kernel cmdline 不写进 header，
而是通过 overlay dtb 写入 `/chosen/bootargs`。

**initramfs**
引导早期的临时根。**必需**：rootfs 所在的存储控制器驱动、显示驱动都是模块（`=m`），
不放进 initramfs 就无法挂载 rootfs / 点亮屏幕。
板级固件（触控 / BT / WLAN / GPU / DSP）也打在 initramfs 里。

**dtbo**
面板选择用的设备树 overlay。piano 的原厂面板是
`qcom,mdss_dsi_p81_35_02_0b_dualdsi_dsc_vid`（双 DSI DSC，video mode）。
处理方式：**把原厂 DTBO 条目与 vendor_boot 基础 DTB 合并进主线 dtb，
不改写设备的 dtbo 分区**（见 ADR-0001）。

**双系统**
Android 与 Ubuntu 并存。两个系统都从槽 A 启动；切换 =
把目标系统的 boot 镜像写入 `boot_a` 并回读校验，不改活动槽位；
`boot_b` 保存一份 Ubuntu boot 镜像作兜底（见 ADR-0002）。

**persist 分区**
存放出厂校准与设备地址。**必须从本机读取，不可跨设备复制**，
刷机前必须备份。

---

## 硬件事实（第二轮实测补充）

**WCN7850 "Peach"**
piano 的 Wi-Fi/蓝牙芯片。主线驱动是 **ath12k**（PCIe），不是 ath11k。
（ath11k 对应 liuqin 的 WCN6855，二者不可混用。）

**gen80600**
piano 的 GPU 固件代号，对应 Adreno 830（DTS `qcom,adreno-44050000`）。
固件 `gen80600_gmu.bin` 在 vendor 分区。

**UFS 模块**
piano 的存储驱动全部编译为模块（`SCSI_UFS_QCOM=m` 等），
因此 **必须放进 initramfs**，否则内核无法挂载 rootfs。

**panel vendor（BOE / CSOT）**
piano 的屏幕有 BOE 与 CSOT 两个供应商，触控固件各有一版
（`novatek_nt36532_piano_fw_{boe,csot}.bin`），因此面板 overlay 的选择是实打实的分支。

**bluetooth_a 分区**
蓝牙固件不在 vendor 分区，而在独立的 `bluetooth_a` 分区（vfat）。
