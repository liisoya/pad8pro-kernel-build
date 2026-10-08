# 15: rootfs 迁入内部存储

**What to build:** 按 piano 分区表在 userdata 尾部划出 Ubuntu 分区，rootfs 迁入，拔掉 U 盘仍能启动。破坏性操作 —— 需先确认已接受清空数据。

**Blocked by:** 14

**Status:** ready-for-human

- [ ] 分区按 piano 布局表划分（破坏性，已确认接受清空数据）
- [ ] rootfs 迁入，fstab / `root=` 参数更新
- [ ] 拔掉 U 盘可正常启动
