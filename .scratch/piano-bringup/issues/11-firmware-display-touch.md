# 11: 固件映射 · 显示 / 触控 / 键盘

**What to build:** 把 GPU（gen80600）、触控（NT36532，BOE/CSOT 两版）、键盘（nanosic）固件打进 initramfs，带 sha256 校验。

**Blocked by:** 09

**Status:** ready-for-agent

- [ ] GPU 固件 gen80600 就位，zap / sqe / aqe 的对应关系已确认
- [ ] 触控固件两版（BOE / CSOT）均就位，与实际面板一致
- [ ] 键盘固件（`MCU_Upgrade.bin`）就位
- [ ] 全部固件带 sha256 pin
