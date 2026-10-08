# 10: 固件映射 · 无线（WLAN / BT）

**What to build:** 把 piano 的 WLAN（WCN7850 / ath12k）与蓝牙固件打进 initramfs，带 sha256 校验。固件必须在 initramfs 阶段就位 —— ath12k 探测发生在 `switch_root` 之前。

**Blocked by:** 09

**Status:** ready-for-agent

- [ ] WLAN 固件（amss / m3 / board-2）就位，来源与版本已记录
- [ ] 蓝牙固件（`brhbtfw20.mbn` vs `gngbtfw20.mbn`）已确定并记录判定依据
- [ ] `wlan_mac.bin` 从本机 persist 读取（不跨设备复制）
- [ ] 全部固件带 sha256 pin 与校验脚本
