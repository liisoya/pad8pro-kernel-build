# 05: 面板 overlay 合并（BOE / CSOT）

**What to build:** 把原厂面板 overlay 与主线 dtb 合并成单一 dtb，并确定 piano 实际用的是 BOE 还是 CSOT 那条。piano 的屏幕有两个面板供应商，触控固件各有一版，所以这不是可有可无的分支。合并后 dtb 必须含正确的面板 compatible。

liuqin 的 dtbo 有 44 条 overlay，piano 只有 1 条 —— 识别逻辑需重写，不能照搬。

**Blocked by:** 04

**Status:** ready-for-agent

- [ ] 从原厂 dtbo 中识别出 piano 实际使用的面板 overlay 条目，并记录 BOE/CSOT 判定依据
- [ ] 合并后 dtb 含 `novatek,nt36532` 与对应面板 compatible
- [ ] 不改写设备 dtbo 分区（合并只发生在构建期）
