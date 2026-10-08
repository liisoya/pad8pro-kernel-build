# Handoff — LinuxforPad

**日期**：2026-10-07
**工作区**：`/home/liisoya/Documents/Project/LinuxforPad`
**交接说明**：本次会话**没有产生任何代码改动**，仅做了只读侦查。下面记录已确认的事实状态与建议的下一步。

---

## 1. 本次会话做了什么

- 收到 `继续` / `请继续执行未完成的任务`，但上下文中没有可恢复的任务列表。
- 尝试从 `~/.codebuddy/`（sessions / projects / history / logs）恢复历史上下文，**未找到任何与本工作区相关的记录**。
- 改为直接侦查工作区本身，得出下面的状态快照。

> 结论：**不存在"未完成的任务"这一上下文**。接手者需要向用户确认要做什么，或按下节建议方向推进。

---

## 2. 工作区当前状态（已核实）

```
LinuxforPad/
├── ci/build-kernel.yml            13.25 KB  GitHub Actions 内核构建
├── device/dts/android-runtime.dts 1.68 MB  42563 行，反编译自 dump 的设备树
├── tools/
│   ├── fetch-aosp-mkbootimg.sh     1.32 KB  拉取并校验 AOSP mkbootimg
│   ├── verify-ccache-wrapper.sh    2.6 KB   ccache wrapper 递归回归测试
│   └── local/
│       ├── downloads/              空
│       └── aosp-mkbootimg/        已解压（mkbootimg.py / unpack_bootimg.py / gki/）
├── notes/                         空目录
└── upstream/                      空目录
```

关键事实：
- **不是 git 仓库**（`git status` 报 `not a git repository`），无版本历史可参考。
- `notes/` 与 `upstream/` 是空占位目录 —— 明显是预留给文档与上游同步的，但从未写入。
- `tools/local/downloads/` 为空，但 `aosp-mkbootimg/` 已解压 —— 说明 `fetch-aosp-mkbootimg.sh` 跑完后归档被清理过，或从别处拷入。
- `tools/local/aosp-mkbootimg/gki/__pycache__/` 存在（`cpython-314`，Python 3.14），说明本机跑过该脚本。

---

## 3. 项目实质（从代码推断）

**目标**：给 Xiaomi Pad 8 Pro（代号 `piano`，SoC = Qualcomm SM8750 / sun）刷 mainstream Linux 内核。

关键引用点（详见文件本身，此处不复制内容）：
- `ci/build-kernel.yml`
  - 内核源固定在外部仓库 `BigfootACA/linux`，默认 ref `469998695964bc26493861cd11f8c17aa764f2e5`
  - 只 `workflow_dispatch`，无 push 触发
  - `universal_defconfig` + `O=out`，构建 `Image` / `dtbs` / `modules`
  - 目标 dtb：`sm8750-xiaomi-piano.dtb`
  - 产物：`dist/pad8pro-$KVER/`（Image、dtb、config、System.map、build-info.txt、SHA256SUMS）+ `modules-$KVER.tar.zst`
  - runner：`ubuntu-24.04`，约 2.5 小时，6848 个模块
- `device/dts/android-runtime.dts` —— 厂商 Android 运行时设备树反编译产物，`model = "Qualcomm Technologies, Inc. Piano based on SM8750"`。**这是把上游内核适配到该机的关键参考物。**

已解决的坑（代码注释里有详细记录，勿重复踩）：
- ccache 必须用 PATH wrapper，不能用 env `CC`（会被 Makefile 的 `CC =` 覆盖）
- wrapper 内部必须用编译器**绝对路径**，否则按名字查找会命中自己 → 无限递归 → 卡死 27 分钟
- `tools/verify-ccache-wrapper.sh` 是该问题的回归测试，改 wrapper 写法后必须重跑

---

## 4. 建议的下一步（按可信度排序）

`notes/` 和 `upstream/` 空着，说明原计划里最关键的产物还没落盘。推荐优先级：

1. **落地进度文档** —— 在 `notes/` 写一份当前状态与待办，避免下次再出现"上下文丢失、无法继续"的情况（本会话的核心问题）。
2. **补齐设备树适配说明** —— 用 `android-runtime.dts` 对照上游 `sm8750-xiaomi-piano.dts`，记录差异（内存布局、reserved-memory、摄像头/显示/触摸节点）。把上游内核源码 checkout 到 `upstream/`。
3. **初始化 git 仓库** —— 当前无版本控制，所有改动无法追溯。
4. **本地跑通构建** —— CI 一次 2.5 小时且烧 Actions 配额，本地先验证 `make ... Image dtbs` 与 `modules_install` 流程。
5. **boot.img 打包链路** —— `tools/` 里已有 mkbootimg，但**还没有任何打包脚本**。CI 只产出裸 `Image`，实际刷机需要用 mkbootimg 打成 `boot.img`（注意 `universal_defconfig` 开了 `CONFIG_KERNEL_ZSTD`，boot header 需 v4+）。这块是明显的缺口。

---

## 5. 接手第一步该做什么

**先问用户。** 本会话无任务上下文，贸然动手可能做错方向。建议开口即确认：

> "上次会话的上下文没能恢复过来（本地也没有历史记录文件）。目前工作区里 `ci/build-kernel.yml`、`device/dts/android-runtime.dts`、`tools/` 已就绪，`notes/` 和 `upstream/` 是空的，git 也没初始化。你想继续的是哪一块——补设备树适配、写 boot.img 打包脚本、还是别的？"

---

## 6. Suggested skills

| Skill | 用途 |
|---|---|
| `diagnosing-bugs` | 若继续方向是排查构建/刷机失败 |
| `research` | 查 SM8750 / sm8750-piano 上游内核状态、GKI、Android boot image v4 规范 |
| `kz-doc-coauthoring` | 写 `notes/` 里的状态文档 / 适配记录 |
| `writing-for-agents` | 若决定建 `AGENTS.md` 固化项目约定 |
| `web_search`（工具，非 skill） | 核实 `BigfootACA/linux` 仓库与该 commit 是否仍可达 |

---

## 7. 保密

本项目未涉及任何凭据。`tools/fetch-aosp-mkbootimg.sh` 中仅有公开的 AOSP 归档 commit 与 sha256 校验值，可安全保留。
