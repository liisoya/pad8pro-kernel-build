# 真机事实清单 —— Xiaomi Pad 8 Pro (piano)

> 只放实测事实，不放推断与决策。决策见 `docs/adr/`，术语见 `CONTEXT.md`。
> 采集日期：2026-10-08，设备当时处于 TWRP recovery。

## 设备身份

| 项 | 值 |
|---|---|
| 型号 | Xiaomi Pad 8 Pro |
| 代号 | piano |
| SoC | Qualcomm SM8750 |
| Android | 16（build `BP2A.250605.031.A2`，SDK 36） |
| 页大小 | **4096**（`ro.boot.hardware.cpu.pagesize`，mkbootimg 必须用它） |
| 当前环境 | TWRP recovery（`product:twrp_piano`） |

** bootloader 已解锁**：能进 TWRP 本身就是解锁了的证据。

## 分区（A/B 双槽，当前 slot = `_a`）

| 分区 | 大小（字节） | 说明 |
|---|---|---|
| `boot_a` / `boot_b` | 100,663,296（96 MiB） | 主引导镜像，空间充足 |
| `vendor_boot_a` / `_b` | 100,663,296（96 MiB） | vendor 侧 ramdisk |
| `init_boot_a` / `_b` | 8,388,608（8 MiB） | GKI 通用 ramdisk |
| `dtbo_a` / `_b` | 25,165,824（24 MiB） | 面板等 overlay |
| `super` | 13,958,643,712（13 GiB） | system/product/vendor/odm 动态分区 |
| `userdata` | **247,954,649,088（约 231 GiB）** | 数据分区，rootfs 候选地 |

TWRP 里 `boot` 是指向 `boot_a` 的符号链接（active slot 指针）。

## 面板（决定 dtbo 怎么处理）

`/proc/cmdline`：

```
msm_drm.dsi_display0=qcom,mdss_dsi_p81_35_02_0b_dualdsi_dsc_vid
msm_drm.panel_build_id=Pff
```

- 面板 = **p81_35_02_0b，双 DSI DSC，video mode**
- 与上游 dts 里的 `xiaomi,p81-boe` / `novatek,nt36532` 节点对应

## 固件分布（在 vendor 分区，TWRP 挂载点 `/piano/vendor-stock`，erofs）

| 用途 | 位置 | 状态 |
|---|---|---|
| GPU（Adreno，SM8750 对应 gen80600） | `firmware/gen80600_gmu.bin`、`gen80000_*` | ✓ 有 |
| 其他代次 GPU（gen70900/gen70e00/gen71700） | `firmware/gen70900_*` 等 | ✓ 有 |
| Wi-Fi 配置 | `firmware/wlan/qca_cld/{wcn7750,kiwi_v2,peach,peach_v2,qca6750}/` | ✓ 有 |
| Wi-Fi / BT / modem 固件 | `firmware_mnt`（modem 分区，vfat） | ✓ 有 |
| BT 固件目录 | `bt_firmware` | ✓ 有 |
| DSP | `dsp` | ✓ 有 |
| **nanosic 键盘 MCU 固件** | vendor 里**没有** | ✗ 待查（需搜 system/product/odm） |

`firmware/` 顶层其余 65 个文件几乎全是 `CAMERA_ICP*`（相机 DSP）。

## 已挂载的可用路径（TWRP）

```
/piano/vendor-stock   ← 原厂 vendor（erofs, ro）
/vendor/firmware_mnt  ← modem 分区（vfat, ro）
/mnt/vendor/persist   ← persist 分区（ext4, ro）
```

---

## 补充实测（2026-10-08，第二轮）

### 存储
- `sda` 逻辑块大小 = **4096**（`blockdev --getbsz`）——与 liuqin 安装器硬校验一致。
- **UFS 驱动全是模块**：`CONFIG_SCSI_UFSHCD=m`、`CONFIG_SCSI_UFSHCD_PLATFORM=m`、
  `CONFIG_SCSI_UFS_QCOM=m`、`CONFIG_BLK_DEV_SD=m`。
  → **必须放进 initramfs**，否则内核找不到 rootfs。（对应模块名待确认：
  `ufshcd-core.ko` / `ufs_qcom.ko` / `sd_mod.ko`）

### 无线（重大修正）
- 芯片 = **WCN7850 "Peach"**（dmesg：`b0000000.qcom,cnss-peach`、`soc:bt_peach`）。
- 主线驱动 = **ath12k**（PCIe），**不是 ath11k**（ath11k 是 liuqin 的 WCN6855）。
- 固件线索：`/vendor/firmware/wlan/qca_cld/peach/`、`peach_v2/`。
- `WCNSS_qcom_cfg.ini` → `/vendor/etc/wifi/peach/`
- **`wlan_mac.bin` 在 `/mnt/vendor/persist/wlan/`** —— 在 persist 分区，本机专属，刷机前必须备份。

### GPU
- **Adreno 830 / gen80600**（DTS `qcom,adreno-44050000`）。
- 固件：`/vendor/firmware/gen80600_gmu.bin`（另有 `gen80000_aqe/sqe/gmu`）。
- 上游 DTS 的 `&gpu { status = "okay"; }` 很简洁，固件名对应关系待确认。

### 触控 / 键盘
- **触控固件在 `/odm/firmware/`**：
  `novatek_nt36532_piano_fw_boe.bin`、`..._fw_csot.bin`、`..._mp_boe.bin`、`..._mp_csot.bin`
  → **存在 BOE 与 CSOT 两个面板厂商**，dtbo 面板选择因此重要。
- **键盘固件 `/odm/firmware/MCU_Upgrade.bin`**（83,436 B）。
- dmesg 显示键盘为 **Nanosic 803**（`nanosic_803_probe`）。

### 蓝牙
- 固件在**独立分区** `bluetooth_a`（vfat，挂到 `/vendor/bt_firmware`），不在 vendor 分区。
- 候选文件：`brhbtfw20.mbn`、`gngbtfw20.mbn`（需确认 piano 用哪个）。
