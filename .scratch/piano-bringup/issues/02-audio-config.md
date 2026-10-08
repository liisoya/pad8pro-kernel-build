# 02: 音频驱动配置收口

**What to build:** 补齐 piano 音频链在内核侧的最后一块配置缺口，使构建出的内核确实包含扬声器功放驱动；并确认固定 commit 里存在 piano 的声卡机器驱动（`qcom,sm8750-sndcard`）。当前 `universal_defconfig` 只启用了同族的 `FS210X`，piano 需要的 `FS19XX` 一族未启用 → 功放驱动不编译 → 声卡注册失败。

**Blocked by:** None (can start immediately)

**Status:** code done, awaiting config_only CI (2026-10-08)

核实结论（全部对照固定 commit `46999869` 的源码，非推断）：
- 功放驱动：`SND_SOC_FS19XX` 存在（`sound/soc/codecs/Kconfig:1318`，`fs19xx.c`
  匹配 `foursemi,fs19xx`），依赖 I2C（实测 =m）；universal_defconfig 只有 FS210X
  → 已把 `CONFIG_SND_SOC_FS19XX=m` 写入 `configs/pad8pro-required.config`。
- 声卡机器驱动：piano.dts 的 sound 节点 `compatible = "qcom,sm8750-sndcard",
  "qcom,sm8450-sndcard"`，由 **`SND_SOC_SC8280XP`**（`sound/soc/qcom/sc8280xp.c:182`
  匹配表含 `qcom,sm8750-sndcard`）提供，universal_defconfig 已有 `=m`，无缺口。
  （注意：不在 sm8250.c —— 该 commit 的 sm8250.c 匹配表只到 sm8250。）
- 模块名：`snd-soc-fs19xx.ko`（对照 `sound/soc/codecs/Makefile:581`），
  已加入 workflow 关键模块断言。
- 待办：跑一次 `config_only` CI 验证片段生效（fs19xx 报 =m）；完整构建顺带验证。

- [x] 必需驱动片段包含音频功放驱动（FS19XX 一族）—— 2026-10-08 已加入
- [ ] `config_only` CI 跑绿，且生效报告里音频驱动为 `=m`
- [x] 已确认声卡机器驱动在固定 commit 中存在；若不存在，记录缺口与补法 —— `SND_SOC_SC8280XP`，见上
