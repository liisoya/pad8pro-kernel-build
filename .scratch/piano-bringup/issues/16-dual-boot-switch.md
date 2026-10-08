# 16: 双系统切换（同槽位）

**What to build:** Android 与 Ubuntu 双向切换，两者都从槽 A 启动。切换 = 把目标系统的 boot 镜像写入 `boot_a` 并回读校验，不改活动槽位；`boot_b` 保存一份 Ubuntu boot 镜像作兜底。见 `docs/adr/0002-dual-boot-same-slot-switching.md`。

**Blocked by:** 15

**Status:** ready-for-human

- [ ] Android ↔ Ubuntu 双向切换可用
- [ ] 切换后回读校验通过
- [ ] `boot_b` 兜底镜像可用
