# Pad 8 Pro（piano）主线 Linux 实现方案

> 状态：**可实现**，方案已定，分 4 阶段推进。
> 依据：本仓库 `notes/DEVICE-FACTS.md`、`notes/PARTITION-LAYOUT.md`、`notes/BUILD-STATUS.md`，
> 参考实现 [yzddmr6/xiaomipad-6pro-mainline](https://github.com/yzddmr6/xiaomipad-6pro-mainline)（liuqin，SM8475）。

---

## 0. 结论

**我知道怎么实现了。** 路线是：复用 liuqin 已真机验证的 **boot/initramfs 架构**，
替换成 piano 自己的内核、设备树与固件映射。两者面板（NT36532 双 DSI DSC）
与键盘（Nanosic）方案相同，SoC 相邻，移植面清晰可控。

当前缺口只有三样：**boot 镜像、initramfs、rootfs**。内核与设备树已经就绪。

---

## 1. 现状盘点

| 组件 | 状态 | 证据 |
|---|---|---|
| 内核 Image | ✅ 已产出 48,429,568 B | CI run 37687294982 |
| 设备树 dtb | ✅ `compatible = "xiaomi,piano","qcom,sm8750"` | dtc 反序列化验证 |
| 模块 | ✅ 8743 个，strip 后 104 MB | 同上 |
| 必需驱动 | ✅ NT36532 / HID_NANOSIC / SC8541 / SC96231 均 `=m` | CI 断言通过 |
| 分区表 | ✅ 已双源核对 | `notes/PARTITION-LAYOUT.md` |
| 设备解锁 | ✅ 可进 TWRP，有 root | adb 实测 |
| **boot.img** | ❌ 缺 | — |
| **initramfs** | ❌ 缺 | — |
| **rootfs** | ❌ 缺 | — |
| **固件映射** | ⚠️ 部分已定位 | 见 §5 |

---

## 2. 目标启动链路

```
XBL（高通 SBL）
  └─ ABL（小米引导器，从 boot_a 的 boot.img 取 kernel/dtb）
       └─ Linux kernel（Image，gzip 包装，boot header v2）
            ├─ cmdline 来自 DTB 的 /chosen/bootargs（不是 boot header！）
            ├─ dtb = 主线 sm8750-xiaomi-piano.dtb + 原厂面板 overlay（烘焙在一起）
            └─ initramfs（busybox + 模块 + 固件）
                 └─ switch_root → rootfs（U 盘 / 内部 userdata 分区）
```

**关键认知**：ABL 从 **DTB 的 `/chosen`** 读命令行，不读 boot header。
这是 liuqin 踩过的坑，必须照做（见 §4.2）。

---

## 3. piano 与 liuqin 的差异清单（必须改的部分）

| 项目 | liuqin（SM8475） | **piano（SM8750）** | 依据 |
|---|---|---|---|
| 内核来源 | 自编译 sm8450 | BigfootACA sm8750 | 本仓库 CI |
| 面板 | NT36532 双 DSI DSC | **相同** | `/proc/cmdline`：`qcom,mdss_dsi_p81_35_02_0b_dualdsi_dsc_vid` |
| 无线 | WCN6855 "Waipio" → **ath11k** | **WCN7850 "Peach" → ath12k** | dmesg `cnss-peach`、`/vendor/firmware/wlan/qca_cld/peach` |
| GPU | Adreno 730 / gen70000 | **Adreno 830 / gen80600** | `/vendor/firmware/gen80600_gmu.bin` |
| 键盘 | Nanosic | **相同** | `/odm/firmware/MCU_Upgrade.bin` 实存 |
| 分区布局 | 锁定 256 GB | **必须重写** | `notes/PARTITION-LAYOUT.md` |
| 声卡拓扑 | 自研 | **需重做** | 待检测（§6） |

> ⚠️ **`ath11k` 是错的**。本仓库 CI 第 284 行断言的 `ath11k*.ko` 是 liuqin 的驱动。
> piano 的无线是 WCN7850，主线驱动为 **ath12k**（`universal_defconfig` 已含
> `CONFIG_ATH12K=m`）。断言虽能通过（ath11k 确实也编译了），但它验的不是 piano 要用的驱动。

---

## 4. 关键技术配方（逐项，含命令）

### 4.1 boot.img 组装

来源：liuqin `tools/lib/build-bootimg.sh`（已读源码）。

```sh
# 1) 压缩内核（v2 header 要求 gzip，与 CONFIG_KERNEL_ZSTD 无关）
gzip -n -9 -c Image > Image.gz

# 2) 组装（pagesize 必须 4096 —— 见 §6 实测项）
python3 tools/local/aosp-mkbootimg/mkbootimg.py \
  --header_version 2 \
  --pagesize 4096 \
  --base 0 \
  --kernel_offset   0x00008000 \
  --ramdisk_offset  0x01000000 \
  --dtb_offset      0x01f00000 \
  --kernel  Image.gz \
  --ramdisk initramfs.cpio.gz \
  --dtb     piano-merged.dtb \
  --cmdline ""
```

- `--cmdline ""` 是**故意的**：命令行走 DTB（§4.2）。
- header **v2**（不是 v4）。liuqin 也是 v2，因为内核先被 gzip 重新包装了。
- 本仓库已有 `tools/local/aosp-mkbootimg`（AOSP 固定版本），直接可用。

### 4.2 cmdline 注入（最容易踩的坑）

```sh
# 生成一个 overlay dtb，把 bootargs 写进 /chosen/bootargs，再合并
cat > bootargs.dts <<'EOF'
/dts-v1/;
/plugin/;
/ {
    fragment@0 {
        target-path = "/chosen";
        __overlay__ { bootargs = "earlycon keep_bootcon console=tty0 \
clk_ignore_unused pd_ignore_unused rootwait ignore_loglevel"; };
    };
};
EOF
dtc -@ -I dts -O dtb -o bootargs.dtbo bootargs.dts
fdtoverlay -i piano.dtb -o piano-with-cmdline.dtb bootargs.dtbo
```

- 必需项：`clk_ignore_unused pd_ignore_unused`（高通主线早期启动必需）、
  `rootwait`（等 rootfs 存储就绪）。
- 具体 console/earlycon 参数需按 piano 实测调整（§6）。

### 4.3 设备树合并（面板 overlay）

liuqin 的做法：取 **原厂 vendor_boot 的 DTBO 条目** + **原厂基础 DTB**，
与主线 dtb 用 `fdtoverlay` 合并，并设 `ABL_OVERLAY_SINK=1 ABL_DTB02_IDS=0`
禁止 ABL 再套 overlay。**不改写设备的 dtbo 分区**。

piano 输入来源：`Xiaomi_Pad8Pro工程小包/images/dtbo.img` 或完整线刷包的 `dtbo.img`
（两包内容不同，见 §6 待定项）。

### 4.4 initramfs 内容

来源：liuqin `tools/lib/build-initramfs.sh`（已读，29 KB）。

必须包含：
1. **busybox**（静态，提供 sh/insmod/mount 等 applet）
2. **`/init`** 脚本：找块设备 → 挂 rootfs → `switch_root`
3. **内核模块**：所有启动期必需的 `=m` 驱动
   - 存储控制器（UFS）—— 否则挂不上 rootfs
   - `msm.ko` + 面板驱动 `panel-novatek-nt36532.ko` —— 否则黑屏
   - `hid-nanosic.ko`（键盘）
4. **固件**（关键！必须放 initramfs 而非 rootfs）：
   liuqin 的注释说明了原因 —— `request_firmware()` 在 initramfs 还是 rootfs 时就会触发
   （触控固件、BT 固件、ath12k 探测都在 `switch_root` 之前），
   只放 stage-2 rootfs 会导致固件加载失败。

piano 固件映射表见 §5。

### 4.5 rootfs

参考 liuqin：Ubuntu Desktop ISO 提取装配 + squashfs + 持久化层。
本项目按已定决策用 **Ubuntu 26.04**（详见 §7 Phase 3）。

---

## 5. piano 固件清单（initramfs 内）

| 用途 | 文件 | 来源 | 状态 |
|---|---|---|---|
| GPU | `gen80600_gmu.bin` | `/vendor/firmware/` | ✅ 已定位（Adreno 830） |
| GPU | zap / sqe / aqe | `/vendor/firmware/gen80000_*` | ⚠️ 对应关系待确认 |
| 无线 | WCN7850 `amss.bin`/`m3.bin`/`board-2.bin` | 上游 linux-firmware `WCN7850/hw2.0/` | ⚠️ 待验证 board-2 是否需自拼 |
| 无线 MAC | `wlan_mac.bin` | **`/mnt/vendor/persist/wlan/`** | ✅ 已定位（在 persist，本机专属） |
| 无线配置 | `WCNSS_qcom_cfg.ini` | `/vendor/etc/wifi/peach/` | ✅ 已定位 |
| 触控 | `novatek_nt36532_piano_fw_{boe,csot}.bin` | **`/odm/firmware/`** | ✅ 已定位（**BOE / CSOT 两版**） |
| 键盘 | `MCU_Upgrade.bin` | **`/odm/firmware/`** | ✅ 已定位（83,436 B，Nanosic 803） |
| BT | `brhbtfw20.mbn` / `gngbtfw20.mbn` | **`bluetooth_a` 分区**（vfat） | ⚠️ 待确认用哪个 |
| DSP | sm8750 DSP 固件 | vendor | ⚠️ 待定位 |
| 音频拓扑 | topology 文件 | 需构建 | ❌ 需重做 |

**initramfs 必需的模块**（实测均为 `=m`）：
`ufshcd-core.ko` / `ufs_qcom.ko` / `sd_mod.ko`（存储，缺则挂不上 rootfs）、
`msm.ko` + `panel-novatek-nt36532.ko`（显示）、`ath12k.ko`（无线）、`hid-nanosic.ko`（键盘）。

---

## 6. 需要提前知道 / 需要检测的事项（checklist）

### 6.1 必须先在真机确认（我可以做）

- [x] **rootfs 存储的驱动是否为 `=m`** —— **是**。`SCSI_UFS_QCOM=m` / `SCSI_UFSHCD=m` / `BLK_DEV_SD=m`，必须进 initramfs。
- [x] **`sda` 逻辑块大小** —— **4096**（与 liuqin 安装器校验一致）。
- [x] **触控固件确切文件名** —— `/odm/firmware/novatek_nt36532_piano_fw_{boe,csot}.bin`。
- [x] **键盘固件** —— `/odm/firmware/MCU_Upgrade.bin`。
- [x] **无线芯片** —— WCN7850 "Peach" → ath12k（已修正 CI 断言）。
- [x] **GPU** —— Adreno 830 / gen80600。
- [x] **`persist` 内容** —— 含 `wlan_mac.bin`（`/mnt/vendor/persist/wlan/`），刷机前必须备份。
- [ ] **initramfs 里 UFS 模块的确切文件名**（`ufshcd-core.ko`? `ufs_qcom.ko`?）—— 构建后从 modules 列表确认。
- [ ] **原厂 dtbo 里 piano 用哪条面板 overlay**（BOE vs CSOT）—— 决定 §4.3 合并哪一条。
- [ ] **BT 固件用 `brhbtfw20.mbn` 还是 `gngbtfw20.mbn`**。
- [ ] **音频：piano 的扬声器/功放型号与需要的 topology**。
- [ ] **ABL 是否接受 header v2**（liuqin 是 SM8475，piano 是 SM8750，需实机验证）。

### 6.2 必须你来决定 / 提供

- [ ] **两版线刷包用哪一版**：工程小包（2025-09-05）vs 完整包 `OS3.0.309.0.WPYCNXM_16.0`（2025-09-06）。
      设备当前指纹 `BP2A.250605.031.A2` —— 需确认哪版与设备当前固件匹配（影响还原）。
- [ ] **是否接受首次刷机清空数据**（若走内部 rootfs，userdata 要缩容）。

### 6.3 风险（已知）

| 风险 | 影响 | 缓解 |
|---|---|---|
| 刷 `boot_a` 失败 | 无法开机 | 先 `dd` 备份原厂 boot_a，`fastboot flash boot` 还原 |
| 改 userdata 分区表 | 数据全丢 | 阶段 3 才做，且先做完整备份 |
| dtb overlay 合并错误 | 黑屏 | 保留原厂 dtbo 不写；先只刷 boot_a 试 |
| `persist` 丢失 | Wi-Fi MAC / 校准丢失，**不可恢复** | 刷机前 `dd` 备份 persist |
| header v2 不被 ABL 接受 | 直接不启动 | 阶段 2 第一件事就是验证；不行改 v4 |

---

## 7. 分阶段实施路线

### Phase 1 —— CI 产出可刷机产物
**目标**：一次构建产出 `boot.img` + `initramfs` + `Image` + `dtb` + `modules`（合并为单个 artifact）。

1. 新增 `tools/build-bootimg.sh`（§4.1 + §4.2 + §4.3）
2. 新增 `tools/build-initramfs.sh`（§4.4 + §5 固件）
3. CI 增加「打包 boot 镜像」步骤；合并两个 artifact 为一个
4. 修正 `ath11k` → `ath12k` 断言

**验收**：artifact 里 `boot.img` 可用 `unpack_bootimg.py` 反解，dtb 含 `/chosen/bootargs`。

### Phase 2 —— 点亮（rootfs 在 USB-C U 盘）
**目标**：屏幕点亮，进 Ubuntu shell。

1. **备份**（不可逆风险所在）：`boot_a` / `vendor_boot_a` / `dtbo_a` / `persist` → 电脑
2. U 盘做 ext4 + Ubuntu 26.04 rootfs
3. `fastboot flash boot boot.img`
4. 开机验证：屏幕、USB、SSH

**验收**：能 SSH 进 Ubuntu，`dmesg` 无致命错误。
**回退**：`fastboot flash boot <原厂 boot.img>`。

### Phase 3 —— rootfs 迁入内部存储
**目标**：不依赖 U 盘。

1. 按 `notes/PARTITION-LAYOUT.md` 在 userdata 尾部划出分区（**破坏性**）
2. rootfs 迁入，改 fstab / cmdline 的 root= 参数

**验收**：拔掉 U 盘仍能启动。

### Phase 4 —— 双系统（可选）
见 `docs/adr/0002-dual-boot-same-slot-switching.md`：
同槽位覆盖切换 + KernelSU 模块。

---

## 8. 与 liuqin 的可复用资产

| 资产 | 复用方式 |
|---|---|
| `tools/lib/build-bootimg.sh` | 照搬，改内核/dtb 路径 |
| `tools/lib/build-initramfs.sh` | 照搬，改固件映射表 |
| `tools/install-layout.sh` | **不能照搬**，需按 piano 布局重写 |
| `device/android/ksu-boot-ubuntu/` | 照搬（双系统切换模块） |
| bootargs 写法、dtb 合并手法 | 照搬 |
| `device/boot/liuqin-mark-slot-successful.c` | 参考 |

---

## 9. 待办

- [ ] §6.1 的检测项逐条跑完，回填本文件
- [ ] Phase 1：写 `build-bootimg.sh` / `build-initramfs.sh`
- [ ] 修正 CI 的 ath11k → ath12k 断言
- [ ] 决定用哪版线刷包做还原源
