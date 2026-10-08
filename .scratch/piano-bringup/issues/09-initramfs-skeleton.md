# 09: initramfs 骨架（busybox + /init + 存储/显示模块）

**What to build:** 一个能挂载 rootfs 并点亮屏幕的最小 initramfs：静态 busybox、`/init`、UFS 存储模块、msm + 面板模块。piano 的存储与显示驱动全是模块（`=m`），不进 initramfs 就挂不上 rootfs、点不亮屏幕。

**Blocked by:** 01, 02

**Status:** ready-for-agent

- [ ] `initramfs.cpio.gz` 生成，cpio 可解包
- [ ] 含静态 busybox 与可执行 `/init`（找块设备 → 挂 rootfs → `switch_root`）
- [ ] 含 UFS 存储模块（否则挂不上 rootfs）与 msm + panel 模块（否则黑屏）
- [ ] 模块清单从构建产物自动生成，而非硬编码猜测
