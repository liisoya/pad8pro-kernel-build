# Pad 8 Pro 内核构建 —— 状态与排障记录

**日期**：2026-10-07
**仓库**：`liisoya/pad8pro-kernel-build`（GitHub Actions）
**目标**：给 Xiaomi Pad 8 Pro（代号 `piano`，SoC = SM8750）构建 mainline Linux 内核
**内核源**：`BigfootACA/linux`，固定 commit `469998695964bc26493861cd11f8c17aa764f2e5`
（= 分支 `full-v7.1.3`）

---

## 1. 结论先行

构建链路本身是通的：**第一次运行（`95f9aff4`，2026-10-07 09:46）就成功产出了内核**，
耗时 2h26m。之后连续 5 次失败，全部是**后加的改动**引入的，没有一次是内核本身编译不过。

已修复并验证通过的问题：

| # | 症状 | 根因 | 状态 |
|---|---|---|---|
| 1 | `缺少配置片段 .../configs/pad8pro-required.config` | workflow 只 checkout 了内核仓库，本仓库从未被检出 | 已修 |
| 2 | 四个驱动全报「未生效」→ NT36532 硬失败 | 断言把整行 `CONFIG_FOO=m` 当符号名，拼出永不匹配的 `^CONFIG_FOO=m=[ym]` | 已修 |
| 3 | ccache wrapper 自检失败（第二次编译未命中） | 只写 `$GITHUB_PATH`，对**当前** step 不生效 | 前一轮已修 |
| 4 | `configure kernel` 卡死 27 分钟 | wrapper 内按名字找编译器 → 命中自己 → 无限递归 | 前一轮已修 |
| 5 | 驱动审计步骤预计 20+ 分钟 | 对每个 compatible 都 rglob 一遍全树 | 已修（改为单次建倒排索引） |

---

## 2. 关键事实（已实测，非推断）

- `universal_defconfig`（8459 行）**确实不含** `CONFIG_DRM_PANEL_NOVATEK_NT36532`，
  补齐片段是必需的。
- 该符号的 Kconfig 依赖 `OF` + `DRM_MIPI_DSI` + `BACKLIGHT_CLASS_DEVICE` 均能满足：
  同依赖的 `NT35510` / `NT36523` 在 `universal_defconfig` 里已经是 `=m`。
- `olddefconfig` 之后实测取值（`config_only` 运行 37644114500 的输出）：

  ```
  CONFIG_DRM_MIPI_DSI=y              CONFIG_I2C=m
  CONFIG_BACKLIGHT_CLASS_DEVICE=m    CONFIG_DRM_MSM=m
  CONFIG_DRM_PANEL_NOVATEK_NT36532=m CONFIG_HID_NANOSIC=m
  CONFIG_CHARGER_SC8541=m            CONFIG_CHARGER_SC96231=m
  ```

- 上游 `sm8750-xiaomi-piano.dts` 存在且已注册（`dts/qcom/Makefile:422`），
  含 `xiaomi,piano` 与 `novatek,nt36532` 两个 compatible。
- 模块断言对应的符号全部为 `=m`：`DRM_MSM`、`ATH11K`、`HID_NANOSIC`；
  面板驱动的 Makefile 确认产出 `panel-novatek-nt36532.o`。

---

## 3. 验证策略：先快后慢

`workflow_dispatch` 有 `config_only` 开关（约 8 分钟，不编译），保留
checkout / 配置 / 编 dtb / 驱动审计四步。改任何配置相关代码后**先跑它**，
不要直接烧 2.5 小时的完整构建。

```
gh workflow run build-kernel.yml -R liisoya/pad8pro-kernel-build \
    --ref main -f config_only=true
```

---

## 4. 本机环境的坑

- **直连 `github.com` 的写操作一律返回 500**：`git push`、REST 的 `PUT` 都失败；
  但 `POST` 和 `PATCH` 正常。
  因此提交要走 Git Data API（blobs → trees → commits → PATCH refs），
  脚本见 `tools/push-via-api.sh`。
- `gh-proxy`（仓库根目录）只加速 git 的 **clone/fetch**，
  它特意保留 `pushInsteadOf` 让 push 直连，所以**对上面的 500 无效**。
- SSH（`git@github.com`）在本机超时不可用。

---

## 5. 待办

- [ ] 完整构建产物验收（Image / dtb / 模块）
- [ ] boot.img 打包：目前只产出裸 `Image`，刷机还需要 mkbootimg 打成镜像
      （`CONFIG_KERNEL_ZSTD=y`，boot header 需 v4+）
- [ ] 面板/键盘驱动是 `=m`，刷机时需要把 `modules-*.tar.zst` 放进 initramfs
- [ ] 用 `device/dts/android-runtime.dts`（厂商 Android 运行时设备树反编译产物）
      对照上游 dts，核对内存布局 / reserved-memory 差异
