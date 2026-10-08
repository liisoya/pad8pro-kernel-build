# Pad 8 Pro（piano）主线 Linux 实现方案

> **版本**：v2（重写版），2026-10-08
> **上一版**：初版（2026-10-07），已废弃。相对初版的修正见 §8。
>
> **本文档的职责**：只写**执行路线、阶段目标、未决问题**。
> 不重复下面四类内容，改动时去改对应来源文件：
>
> | 内容 | 唯一来源 |
> |---|---|
> | 术语表 | `CONTEXT.md` |
> | 决策及其理由 | `docs/adr/` |
> | 实测事实 | `notes/DEVICE-FACTS.md`、`notes/PARTITION-LAYOUT.md`、`notes/BUILD-STATUS.md` |
> | 任务分解与依赖 | `.scratch/piano-bringup/`（16 张 ticket） |

---

## 0. 结论

路线不变：**复用 liuqin 已真机验证的 boot / initramfs 架构**（ADR-0001），
替换成 piano 自己的内核、设备树与固件映射。面板（NT36532 双 DSI DSC）与键盘
（Nanosic）方案相同，SoC 相邻（SM8475 → SM8750），移植面可控。

与初版判断不同的是：**内核侧已经全部完成并验证**（内核、dtb、模块、配置片段、CI 链路）。
真正剩下的缺口只有一个 —— **打包设施**。仓库里目前没有任何脚本把 `Image` + dtb + 模块
打成可刷的 `boot.img` 与 `initramfs`，也没有任何 CI 步骤产出它们。

---

## 1. 现状盘点

| 组件 | 状态 | 证据 |
|---|---|---|
| 内核 `Image` | ✅ 48,429,568 B | `notes/BUILD-STATUS.md` §1 |
| 设备树 dtb | ✅ `compatible = "xiaomi,piano","qcom,sm8750"` | 同上 |
| 模块 | ✅ 8743 个，strip 后 104 MB | 同上 |
| 必需驱动（显示/键盘/充电） | ✅ 均 `=m` 且实际产出 `.ko` | CI 断言 |
| CI 构建链路 | ✅ 已跑通（含 ccache、磁盘释放、config_only 快验） | `.github/workflows/build-kernel.yml` |
| 分区表 | ✅ 双源核对，布局逐项一致 | `notes/PARTITION-LAYOUT.md` |
| 无线驱动 | ✅ ath11k → ath12k 已修正 | workflow 模块断言 |
| 设备解锁 | ✅ 可进 TWRP | `notes/DEVICE-FACTS.md` |
| **打包设施** | ❌ 不存在 | `tools/` 下无 `build-bootimg.sh` / `build-initramfs.sh` |
| **boot.img** | ❌ 缺 | — |
| **initramfs** | ❌ 缺 | — |
| **rootfs** | ❌ 缺 | — |
| **固件映射** | ⚠️ 已定位，未落盘 | `notes/DEVICE-FACTS.md` §固件分布 |
| **音频配置** | ✅ 配置缺口已补（待 CI 验证） | ticket 02：`SND_SOC_FS19XX=m` 已入 required.config；机器驱动 `SND_SOC_SC8280XP=m` 已在 defconfig（sc8280xp.c 匹配表含 sm8750-sndcard） |

---

## 2. 目标启动链路

```
XBL（高通 SBL）
  └─ ABL（小米引导器，从 boot_a 的 boot.img 取 kernel / dtb）
       └─ Linux kernel（Image，gzip 重压后装进 boot header）
            ├─ cmdline 来自 DTB 的 /chosen/bootargs（不是 boot header！）
            ├─ dtb = 主线 sm8750-xiaomi-piano.dtb
            │        + 原厂面板 overlay + ABL 身份镜像 + __symbols__（构建期烘焙在一起）
            └─ initramfs（busybox + 启动期模块 + 板级固件）
                 └─ switch_root → rootfs（U 盘 → 内部 userdata 分区）
```

**三个"一错就黑屏/不启动"的约束**（全部有 ticket 对应）：

1. ABL 从 **DTB 的 `/chosen`** 读命令行，不读 boot header → ticket 06
2. dtb 必须带**与设备原厂一致的 `msm-id` / `board-id`**，否则 ABL 拒绝启动 → ticket 07
3. dtb 必须有 **`__symbols__`**，并禁止 ABL 二次套 overlay → ticket 08

---

## 3. 与 liuqin 的差异（仍需逐项处理的部分）

| 项目 | liuqin（SM8475） | piano（SM8750） | 处理 |
|---|---|---|---|
| 内核来源 | 自编译 sm8450 | BigfootACA sm8750 固定 commit | 已有 |
| 面板 | NT36532 双 DSI DSC | **相同** | 复用 |
| 面板 vendor | 单一 | **BOE / CSOT 两版**（触控固件各一版） | 分支，见 §6.2 |
| 无线 | WCN6855 → **ath11k** | **WCN7850 "Peach" → ath12k** | 已修正 |
| GPU | Adreno 730 / gen70000 | **Adreno 830 / gen80600** | 固件换名 |
| 键盘 | Nanosic | **相同** | 复用 |
| 蓝牙固件位置 | vendor | **独立 `bluetooth_a` 分区（vfat）** | 需从分区取 |
| 分区布局 | 锁定 256 GB | **布局不同，必须重写** | `notes/PARTITION-LAYOUT.md` |
| 声卡拓扑 | 自研（有构建脚本） | **需重做** | ticket 12 |
| dtbo 条目结构 | 44 条 overlay | **结构与数量都不同** | 识别逻辑需重写 |

---

## 4. 执行模型：16 张 ticket

执行单位已从初版的「4 个阶段」细化为 **16 张 ticket**，位于 `.scratch/piano-bringup/issues/`。
编号即依赖顺序（blocker 编号一定更小）。依赖图与关键路径见
`.scratch/piano-bringup/README.md`。

```
01 工具骨架 ──┬─> 04 boot.img ─> 05 面板overlay ─> 06 cmdline ─> 07 ABL身份 ─> 08 __symbols__
              │                                                                      │
02 音频配置 ──┴─> 09 initramfs ──┬─> 10 固件·无线 ──────────────────────────────────┤
                                 ├─> 11 固件·显示触控键盘 ─────────────────────────┤
                                 └─> 12 固件·音频（还需 02）────────────────────────┤
                                                                                    v
03 设备备份 ─────────────────────────────────────────────────────> 13 CI 单一可刷 artifact
                                                                                    │
                                                                                    v
                                                                    14 首次点亮（还需 03）
                                                                                    │
                                                                                    v
                                                                    15 rootfs 迁入内部存储
                                                                                    │
                                                                                    v
                                                                    16 双系统切换
```

**阶段映射**（沿用初版的四阶段，便于对照）：

| 阶段 | 目标 | ticket |
|---|---|---|
| Phase 1 | CI 产出单一可刷 artifact | 01、02、04–13 |
| Phase 2 | 首次点亮（rootfs 在 USB-C） | 03、14 |
| Phase 3 | rootfs 迁入内部存储 | 15 |
| Phase 4 | 双系统切换（可选） | 16 |

**不需要真机、可本地或 CI 验证**的：01、02、04–13。
**必须真机人工执行**的：03、14、15、16。

---

## 5. 关键技术要点

细节落在对应 ticket 与 ADR，这里只记最容易踩的坑。

### 5.1 boot.img
- `--pagesize 4096` 必须与真机 `ro.boot.hardware.cpu.pagesize` 一致（已实测 4096）。
- mkbootimg 参数固定，见 ADR-0001。参考实现的 `build-bootimg.sh` 用
  `--header_version 2` + `gzip -n -9` 重压 `Image`。
- **header 版本是本项目最大的未决项**，见 §6.1。
- 参考实现用「解包后 `cmp` 逐字节回比」验证产物（`Image.gz` / dtb / ramdisk 三项），
  这个验证手法值得照抄。

### 5.2 cmdline
写进 dtb 的 `/chosen/bootargs`，**不写 boot header**。必需项
`clk_ignore_unused pd_ignore_unused rootwait`（高通主线早期启动必需）。

### 5.3 dtb 合并
原厂面板 overlay + 主线 dtb 用 `fdtoverlay` 烘焙成单一 dtb，再叠加 ABL 身份镜像与
`__symbols__`，并设 `ABL_OVERLAY_SINK=1 ABL_DTB02_IDS=0` 禁止 ABL 再套 overlay。
**不改写设备的 dtbo 分区**（ADR-0001）。

### 5.4 initramfs
必须含：静态 busybox、`/init`、**UFS 存储模块**（否则挂不上 rootfs）、
`msm.ko` + 面板模块（否则黑屏）、以及**板级固件**。
固件必须放 initramfs 而非 rootfs —— `request_firmware()` 在 `switch_root` 之前就会触发。

### 5.5 rootfs
Ubuntu 26.04。先做 USB-C U 盘版（Phase 2），跑通后再迁入内部存储（Phase 3）。

---

## 6. 未决问题与风险

### 6.1 boot header 版本：v2 还是 v4+（**文档内部就矛盾**）

| 来源 | 说法 |
|---|---|
| `docs/adr/0001`（决策） | **v2** —— `Image` 先 `gzip -n -9` 重压，`CONFIG_KERNEL_ZSTD=y` 不构成障碍 |
| `CONTEXT.md`（术语表） | **v4+** —— "ZSTD 压缩，打 boot 镜像时 header 必须是 v4+" |
| `notes/BUILD-STATUS.md` | **v4+** —— 同上 |
| 参考实现 `build-bootimg.sh` | 实测 `--header_version 2` + `gzip -n -9` |

**判断**：以 ADR-0001 的 v2 为准（参考实现已在同族 bootloader 上验证），
`CONTEXT.md` 与 `BUILD-STATUS.md` 的 v4+ 说法是早期推断，应回填修正。
但 SM8475 → SM8750 的 bootloader 是否同样接受 v2 **尚未在 piano 上实测**。

**裁决点**：ticket 04 产出 v2 产物，ticket 14 真机验证；不接受则回退 v4。

### 6.2 面板 vendor：BOE 还是 CSOT
原厂 dtbo 里 piano 用的是哪一条 overlay，决定合并哪条、以及用哪版触控固件
（`novatek_nt36532_piano_fw_{boe,csot}.bin` 两版实存）。→ ticket 05

### 6.3 其余待确认项
- 蓝牙固件选型：`brhbtfw20.mbn` vs `gngbtfw20.mbn`。→ ticket 10
- 音频拓扑需为 piano 构建；DSP 固件位置待定。→ ticket 12
- initramfs 里 UFS 模块的确切文件名（构建后从模块列表确认，不要猜）。→ ticket 09

### 6.4 音频配置缺口（✅ 已补，2026-10-08）
2026-10-08 核实（全部对照固定 commit 源码）：
- 功放：`SND_SOC_FS19XX=m` 已补入 `configs/pad8pro-required.config`
  （universal_defconfig 只有 `FS210X`；`fs19xx.c` 匹配 piano.dts 的
  `foursemi,fs19xx`，共 4 个扬声器节点）。
- 机器驱动：**无缺口** —— piano.dts sound 节点走 fallback compatible
  `qcom,sm8450-sndcard`/`qcom,sm8750-sndcard`，由 `SND_SOC_SC8280XP`
  （`sc8280xp.c:182`）绑定，defconfig 已有 `=m`。注意它**不在** sm8250.c
  （该 commit 的 sm8250.c 匹配表只到 sm8250）。
- 模块名 `snd-soc-fs19xx.ko` 已加入 workflow 关键模块断言。
- 剩余：跑 `config_only` CI 确认片段生效（ticket 02 验收项 2）——
  ✅ run `37728417954`（2026-10-08）`OK CONFIG_SND_SOC_FS19XX=m`，已跑绿。

### 6.5 工程环境约束（会影响怎么改 CI）
- **`tools/local/` 被 `.gitignore` 忽略**：本地预取的 `aosp-mkbootimg` 进不了仓库，
  CI 必须用 `tools/fetch-aosp-mkbootimg.sh` 现场拉取并以 sha256 锁定身份。
- **本机对 github.com 的写操作返回 500**（`git push`、REST `PUT`），
  改 CI 要走 Git Data API，脚本见 `tools/push-via-api.sh`。

### 6.6 风险表

| 风险 | 影响 | 缓解 |
|---|---|---|
| 刷 `boot_a` 失败 | 无法开机 | 先 `dd` 备份原厂 `boot_a`，`fastboot flash boot` 还原 |
| header v2 不被 piano ABL 接受 | 直接不启动 | Phase 2 第一件事就验证；不行改 v4 |
| dtb overlay / 身份镜像合并错误 | 黑屏或不启动 | 保留原厂 dtbo 不写；先只刷 `boot_a` 试 |
| `persist` 丢失 | Wi-Fi MAC / 出厂校准丢失，**不可恢复** | 刷机前 `dd` 备份 persist，且只从本机读 |
| 缩小 `userdata` | 数据全丢 | 放到 Phase 3，且先做完整备份 |
| 切换脚本未经验证 | 卡在某一系统 | 保留 `boot_b` 兜底镜像（ADR-0002） |

---

## 7. 与 liuqin 的复用边界

参考实现已 checkout 到本仓库的 `xiaomipad-6pro-mainline-main/`（**未提交**）。

| 资产 | 复用方式 |
|---|---|
| `tools/lib/build-bootimg.sh` | 照搬骨架，改内核 / dtb 路径与固件表 |
| `tools/lib/build-initramfs.sh` | 照搬骨架，改固件映射表 |
| `tools/lib/install-layout.sh` | **不能照搬** —— 锁定 256 GB 且分区编号不同，必须按 piano 布局重写 |
| `device/android/ksu-boot-ubuntu/` | 照搬（双系统切换模块） |
| bootargs 写法、dtb 合并手法、解包回比验证 | 照搬 |

---

## 8. 相对初版的修正

| # | 初版说法 | 现在的事实 |
|---|---|---|
| 1 | CI 文件路径 `ci/build-kernel.yml` | 实为 `.github/workflows/build-kernel.yml` |
| 2 | "修正 ath11k → ath12k 断言"列为待办 | **已完成**，workflow 模块断言已用 `ath12k*.ko` |
| 3 | "当前缺口只有三样：boot 镜像、initramfs、rootfs" | 更准确的表述：**打包设施整体不存在**，是唯一主要工程量 |
| 4 | 未提音频功放配置 | 补记：配置片段缺 `FS19XX` 一族（§6.4） |
| 5 | 未提本地工具与 CI 的关系 | 补记：`tools/local/` 被 gitignore，CI 必须现场拉取 mkbootimg（§6.5） |
| 6 | 未提本机 GitHub 写操作 500 | 补记（§6.5） |
| 7 | 未提 `device/dts/android-runtime.dts` | 该参考物已存在（42563 行，厂商运行时设备树反编译产物） |
| 8 | 决策散落在正文 | 已固化为 `docs/adr/0001`、`docs/adr/0002` |
| 9 | 分区表为单一来源 | 已双源交叉验证，布局逐项一致 |
| 10 | 任务为 4 个阶段 | 细化为 16 张 ticket，含依赖图与关键路径 |
| 11 | boot header 版本单方面写 v2 | 记录为**文档内部矛盾**，列为未决项（§6.1） |

---

## 9. 待办

- [x] §6.1 回填 `CONTEXT.md` 与 `notes/BUILD-STATUS.md` 的 boot header 版本说法（改为 v2，或标注"待真机裁决"）—— 已回填（2026-10-08）；ticket 04 产出 v2 产物，真机裁决留 ticket 14
- [ ] 按 §4 的 frontier 推进：先做 01 / 02 / 03（无 blocker）
- [ ] §6.2 / §6.3 的待确认项逐条跑完后回填对应 ticket
- [ ] `xiaomipad-6pro-mainline-main/` 是否入库：483 个文件未提交，需决定（参考物 vs 体积）
