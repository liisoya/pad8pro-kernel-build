# 12: 固件映射 · 音频（拓扑 + DSP）

**What to build:** 产出 piano 的音频拓扑并打进 initramfs，配合 02 的功放驱动与 DSP 固件，使扬声器可用。拓扑必须放在与声卡 compatible 对应的固件路径下（liuqin 放在 `sm8450/`，piano 应对应 `sm8750/`）。

**Blocked by:** 02, 09

**Status:** ready-for-agent

- [ ] piano 音频拓扑文件生成，落到与声卡 compatible 对应的固件路径
- [ ] DSP 固件就位
- [ ] 拓扑被打入 initramfs
