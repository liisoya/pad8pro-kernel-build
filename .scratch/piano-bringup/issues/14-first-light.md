# 14: 首次点亮（rootfs 在 USB-C）

**What to build:** 刷入 `boot.img` 后屏幕点亮并进入 Ubuntu shell。这是整个项目的第一个真机里程碑，也是 header v2/v4 假设的最终裁决点（见 04）。

**Blocked by:** 03, 13

**Status:** ready-for-human

- [ ] 屏幕点亮
- [ ] 能进 Ubuntu shell / SSH
- [ ] dmesg 无致命错误
- [ ] 回退路径已验证（刷回原厂 boot.img 能回到原状态）
