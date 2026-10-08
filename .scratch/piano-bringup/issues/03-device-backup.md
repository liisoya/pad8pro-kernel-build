# 03: 设备分区备份

**What to build:** 在改动任何分区之前，把四份不可逆的分区镜像完整备份到电脑：`boot_a`、`vendor_boot_a`、`dtbo_a`、`persist`。`persist` 含本机专属的 Wi-Fi MAC 与出厂校准，丢了不可恢复、不可跨设备复制。

**Blocked by:** None (can start immediately)

**Status:** ready-for-human

- [ ] 四份镜像均已 `dd` 出来并落到电脑
- [ ] 每份附 sha256 校验值，回读一致
- [ ] 原厂 boot 镜像可直接用于回退（`fastboot flash boot`）
