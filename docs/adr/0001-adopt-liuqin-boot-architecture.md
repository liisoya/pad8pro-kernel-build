# ADR-0001 采用 liuqin 的 boot / initramfs 架构

**状态**：已采纳（2026-10-08）
**参考**：[yzddmr6/xiaomipad-6pro-mainline](https://github.com/yzddmr6/xiaomipad-6pro-mainline) v0.6.0

## 背景

刷入真机需要 boot 镜像 + initramfs + 固件，而 BigfootACA/linux 是纯内核树，
不提供任何打包设施。自己从零设计风险高。

同一厂商、同一块面板（Novatek NT36532 双 DSI DSC）、同一磁吸键盘方案（Nanosic）
的 liuqin（Xiaomi Pad 6 Pro / SM8475）项目已实现完整可用链路并经真机验收。
差异只在 SoC（SM8475 → SM8750），而 SoC 侧 piano 已有 BigfootACA 内核。

## 决策

采用 liuqin 的 boot/initramfs 架构，要点：

1. **boot header 用 v2**。Image 先 `gzip -n -9` 重新压缩，因此 `CONFIG_KERNEL_ZSTD=y`
   不构成障碍，也无需 v4 header。
2. **mkbootimg 参数固定**：`--header_version 2 --pagesize 4096 --base 0
   --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --dtb_offset 0x01f00000`。
   `pagesize 4096` 必须与真机 `ro.boot.hardware.cpu.pagesize` 一致。
3. **kernel cmdline 不写入 boot header**，改为生成一个 overlay dtb，
   用 `fdtoverlay` 写入 `/chosen/bootargs`。原因是 ABL 从 DTB 而非 header 取命令行。
   必需 bootargs 含 `clk_ignore_unused pd_ignore_unused rootwait`。
4. **面板 overlay 烘焙进 dtb**：取原厂 vendor_boot 的 DTBO 条目 + 基础 DTB 与主线 dtb
   合并（`ABL_OVERLAY_SINK=1 ABL_DTB02_IDS=0` 禁止 ABL 再套 overlay），
   **不改写设备的 dtbo 分区**。
5. **固件打进 initramfs**（触控 / BT / WLAN board file / GPU / DSP / 音频拓扑），
   而非放入 rootfs —— 这样开机即可点亮屏幕并连接无线。
6. mkbootimg / unpack_bootimg 用 AOSP 固定版本并以 sha256 锁定身份。
   本仓库已有 `tools/fetch-aosp-mkbootimg.sh` 与 `tools/local/aosp-mkbootimg`。

## 后果

- 需要为 piano 重写固件映射表（SM8475→SM8750：GPU 变 `gen80600*`，
  WLAN 型号不同，音频拓扑需重做）。
- initramfs 构建是新增的构建环节，CI 复杂度上升。
- 好处：面板选择、cmdline、固件加载这些「一错就黑屏」的难点全部复用已验证方案。
