# ADR-0002 双系统采用「同槽位覆盖切换」而非 A/B 槽位切换

**状态**：已采纳（2026-10-08）
**前置**：ADR-0001

## 背景

piano 是 A/B 双槽设备（boot_a/b、dtbo_a/b、init_boot_a/b），当前活动槽 `_a`。
要在保留 Android 的同时安装 Ubuntu，需要一个系统切换机制。

设备分区事实（见 `notes/DEVICE-FACTS.md`）：`boot_a/b` 各 96 MiB，
`userdata` 约 231 GiB，sda 逻辑块大小 4096。

## 决策

沿用 liuqin 的方案：**两个系统都从槽 A 启动**。

- 切换 = 把目标系统的 boot 镜像写入 `boot_a`，**回读校验**后再重启；不改活动槽位。
- `boot_b` 保存一份 Ubuntu boot 镜像作为兜底：`boot_a` 加载失败时 bootloader 自动改用 `boot_b`。
- Ubuntu 侧提供「重启到 Android」入口；Android 侧通过 KernelSU 模块提供
  「重启到 Ubuntu」（`boot-ubuntu` → 同一个 switcher 的 `to-ubuntu`）。
- 分区上缩小 Android `userdata`，在 Ubuntu 侧新建独立分区。

## 为什么不用 A/B 槽位切换

把 Android 放 `_b`、Ubuntu 放 `_a` 看似更自然，但会牵动 super 分区的槽位镜像、
verity/avb 元数据与原厂恢复逻辑，出错面远大于「只覆写 boot_a」。
同槽位方案只碰一个 96 MiB 分区，风险最小，且已被 liuqin 真机验证过思路。

## 后果与风险

- **缩小 userdata 是破坏性操作，会清空数据**。首次执行必须先备份
  `boot_a`、`vendor_boot_a`、`dtbo_a` 与出厂 `persist`（persist 含本机校准，
  不可跨设备复制，必须从本机读取）。
- Android 侧需要安装 KernelSU 才能提供切换入口。
- liuqin 作者自己标注两个方向的切换「尚未经真机验证」——搬到 piano 后同样要按
  此纪律对待。
- liuqin 的安装器锁定 256 GB 布局并校验 sda 逻辑块大小=4096、
  `userdata` 在 sda 且 PARTNAME 唯一、容量 ≥16 GiB。**piano 已实测满足后三项**，
  但分区编号与起始偏移不同，布局表必须为 piano 重写，不得照搬。

## 分阶段路线（对应 Q2=C 的渐进）

1. 备份 `boot_a` / `vendor_boot_a` / `dtbo_a` / `persist` → 刷主线 boot 镜像，
   rootfs 放 USB-C OTG —— 验证能开机（此阶段完全不碰内部存储布局）。
2. 跑通后，参照 liuqin `install-layout.sh` 在 userdata 尾部划出 Ubuntu 分区。
3. 安装 KernelSU 模块，实现 Android ↔ Ubuntu 双向切换。
