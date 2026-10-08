# piano 分区表（来自小米线刷包，已与真机实测核对）

> 来源：`Xiaomi_Pad8Pro工程小包-已测试-用于解锁BL/images/rawprogram*.xml`（QFIL 格式）。
> 扇区大小 **4096**（`SECTOR_SIZE_IN_BYTES`）。共 6 个 UFS LUN，对应设备 `sda`~`sdf`。
>
> **已用第二个来源交叉验证**：完整线刷包
> `piano_images_OS3.0.309.0.WPYCNXM_16.0/images/gpt_main0~5.bin`（fastboot 方式）
> 与本表**布局完全一致**——6 个 LUN、134 个分区、LUN 归属与大小逐项相同；
> 两个包的 `gpt_*.bin` 字节级不同只是每版 ROM 生成的分区 GUID 不同，不代表布局差异。
>
> 真机对照（按 LUN 逐个核对）：boot / dtbo / vendor_boot / init_boot / super /
> persist / metadata / misc / modemst1/2 / vbmeta 大小与 LUN 归属全部一致。
> `userdata` 包内为 0：线刷不写数据分区，实际大小由 `patch0.xml` 烧写时按
> `NUM_DISK_SECTORS-6` 扩到磁盘尾部（真机实测 230.93 GB，位于 `sda34`）。
> 含 `NUM_DISK_SECTORS-N` 表达式的条目在 QFIL 烧写时才解析，此处起始扇区留空。

## LUN 0（sda）

| 分区名 | 起始扇区 | 扇区数 | 大小 | 包内镜像 |
|---|---:|---:|---:|---|
| PrimaryGPT | 0 | 6 | 0.0 MB | gpt_main0.bin |
| switch | 6 | 2 | 0.0 MB | — |
| ssd | 8 | 8 | 0.0 MB | — |
| dbg | 16 | 8 | 0.0 MB | — |
| bk01 | 24 | 8 | 0.0 MB | — |
| secinfo | 32 | 32 | 0.1 MB | — |
| bk03 | 64 | 64 | 0.2 MB | — |
| bk04 | 128 | 128 | 0.5 MB | — |
| keystore | 256 | 128 | 0.5 MB | — |
| frp | 384 | 128 | 0.5 MB | frp_erase.mbn |
| countrycode_a | 512 | 256 | 1.0 MB | countrycode.img |
| countrycode_b | 768 | 256 | 1.0 MB | countrycode.img |
| misc | 1024 | 1024 | 4.0 MB | misc.img |
| bk05 | 2048 | 2048 | 8.0 MB | — |
| logfs | 4096 | 2048 | 8.0 MB | logfs_ufs_8mb.bin |
| ffu | 6144 | 2048 | 8.0 MB | — |
| vm-persist | 8192 | 9728 | 38.0 MB | — |
| vm-bootsys_a | 17920 | 5120 | 20.0 MB | vm-bootsys.img |
| vm-bootsys_b | 23040 | 5120 | 20.0 MB | vm-bootsys.img |
| mbnconfig | 28160 | 8192 | 32.0 MB | — |
| metadata | 36352 | 16384 | 64.0 MB | metadata.img |
| devinfo | 52736 | 2 | 0.0 MB | — |
| vbmeta_system_a | 52738 | 32 | 0.1 MB | vbmeta_system.img |
| vbmeta_system_b | 52770 | 32 | 0.1 MB | vbmeta_system.img |
| bk07 | 52802 | 1214 | 4.7 MB | — |
| charger | 54016 | 256 | 1.0 MB | — |
| blackbox | 54272 | 41984 | 164.0 MB | — |
| oops | 96256 | 4096 | 16.0 MB | — |
| rawdump | 100352 | 76800 | 300.0 MB | — |
| opconfig | 177152 | 5120 | 20.0 MB | — |
| mem | 182272 | 1024 | 4.0 MB | — |
| mtdblk | 183296 | 8192 | 32.0 MB | — |
| rescue | 191488 | 32768 | 128.0 MB | rescue.img |
| super | 224256 | 3407872 | 13.00 GB | — |
| userdata | 3632128 | 0 | 0.0 MB | userdata.img |
| BackupGPT | 表达式 | 5 | 0.0 MB | gpt_backup0.bin |

## LUN 1（sdb）

| 分区名 | 起始扇区 | 扇区数 | 大小 | 包内镜像 |
|---|---:|---:|---:|---|
| PrimaryGPT | 0 | 6 | 0.0 MB | gpt_main1.bin |
| xbl_a | 6 | 2048 | 8.0 MB | xbl_s.melf |
| xbl_config_a | 2054 | 128 | 0.5 MB | xbl_config.elf |
| multiimgqti_a | 2182 | 8 | 0.0 MB | multi_image_qti.mbn |
| multiimgoem_a | 2190 | 8 | 0.0 MB | multi_image.mbn |
| apdp | 2198 | 64 | 0.2 MB | apdp_minidump.mbn |
| last_parti | 2262 | 0 | 0.0 MB | — |
| BackupGPT | 表达式 | 5 | 0.0 MB | gpt_backup1.bin |

## LUN 2（sdc）

| 分区名 | 起始扇区 | 扇区数 | 大小 | 包内镜像 |
|---|---:|---:|---:|---|
| PrimaryGPT | 0 | 6 | 0.0 MB | gpt_main2.bin |
| xbl_b | 6 | 2048 | 8.0 MB | xbl_s.melf |
| xbl_config_b | 2054 | 128 | 0.5 MB | xbl_config.elf |
| multiimgqti_b | 2182 | 8 | 0.0 MB | multi_image_qti.mbn |
| multiimgoem_b | 2190 | 8 | 0.0 MB | multi_image.mbn |
| apdpb | 2198 | 64 | 0.2 MB | apdp_minidump.mbn |
| last_parti | 2262 | 0 | 0.0 MB | — |
| BackupGPT | 表达式 | 5 | 0.0 MB | gpt_backup2.bin |

## LUN 3（sdd）

| 分区名 | 起始扇区 | 扇区数 | 大小 | 包内镜像 |
|---|---:|---:|---:|---|
| PrimaryGPT | 0 | 6 | 0.0 MB | gpt_main3.bin |
| ALIGN_TO_128K_1 | 6 | 26 | 0.1 MB | — |
| cdt | 32 | 32 | 0.1 MB | — |
| ddr | 64 | 512 | 2.0 MB | zeros_5sectors.bin |
| last_parti | 576 | 0 | 0.0 MB | — |
| BackupGPT | 表达式 | 5 | 0.0 MB | gpt_backup3.bin |

## LUN 4（sde）

| 分区名 | 起始扇区 | 扇区数 | 大小 | 包内镜像 |
|---|---:|---:|---:|---|
| PrimaryGPT | 0 | 6 | 0.0 MB | gpt_main4.bin |
| uefi_a | 6 | 1280 | 5.0 MB | uefi.elf |
| idmanager_a | 1286 | 128 | 0.5 MB | idmanager.mbn |
| aop_a | 1414 | 128 | 0.5 MB | aop.mbn |
| aop_config_a | 1542 | 128 | 0.5 MB | aop_devcfg.mbn |
| tz_a | 1670 | 1280 | 5.0 MB | tz.mbn |
| hyp_a | 2950 | 2048 | 8.0 MB | hypvmperformance.mbn |
| modem_a | 4998 | 51712 | 202.0 MB | — |
| bluetooth_a | 56710 | 2048 | 8.0 MB | BTFM.bin |
| abl_a | 58758 | 2048 | 8.0 MB | abl.elf |
| dsp_a | 60806 | 16384 | 64.0 MB | dspso.bin |
| keymaster_a | 77190 | 128 | 0.5 MB | keymint.mbn |
| spuservice_a | 77318 | 32 | 0.1 MB | spu_service.mbn |
| boot_a | 77350 | 24576 | 96.0 MB | boot.img |
| devcfg_a | 101926 | 64 | 0.2 MB | devcfg.mbn |
| qupfw_a | 101990 | 32 | 0.1 MB | qupv3fw.elf |
| vbmeta_a | 102022 | 32 | 0.1 MB | vbmeta.img |
| dtbo_a | 102054 | 6144 | 24.0 MB | dtbo.img |
| uefisecapp_a | 108198 | 512 | 2.0 MB | uefi_sec.mbn |
| imagefv_a | 108710 | 12288 | 48.0 MB | imagefv.elf |
| shrm_a | 120998 | 64 | 0.2 MB | shrm.elf |
| cpucp_a | 121062 | 256 | 1.0 MB | cpucp.elf |
| featenabler_a | 121318 | 32 | 0.1 MB | featenabler.mbn |
| vendor_boot_a | 121350 | 24576 | 96.0 MB | vendor_boot.img |
| qmcs | 145926 | 7680 | 30.0 MB | — |
| qweslicstore_a | 153606 | 64 | 0.2 MB | — |
| recovery_a | 153670 | 25600 | 100.0 MB | recovery.img |
| xbl_ramdump_a | 179270 | 512 | 2.0 MB | XblRamdump.elf |
| init_boot_a | 179782 | 2048 | 8.0 MB | init_boot.img |
| cpucp_dtb_a | 181830 | 16 | 0.1 MB | cpucp_dtbs.elf |
| pvmfw_a | 181846 | 256 | 1.0 MB | pvmfw.img |
| soccp_debug_a | 182102 | 128 | 0.5 MB | sdi.mbn |
| soccp_dcd_a | 182230 | 6 | 0.0 MB | dcd.mbn |
| pdp_a | 182236 | 64 | 0.2 MB | pdp.elf |
| pdp_cdb_a | 182300 | 32 | 0.1 MB | pdp_cdb.elf |
| uefi_b | 182332 | 1280 | 5.0 MB | uefi.elf |
| idmanager_b | 183612 | 128 | 0.5 MB | idmanager.mbn |
| aop_b | 183740 | 128 | 0.5 MB | aop.mbn |
| aop_config_b | 183868 | 128 | 0.5 MB | aop_devcfg.mbn |
| tz_b | 183996 | 1280 | 5.0 MB | tz.mbn |
| hyp_b | 185276 | 2048 | 8.0 MB | hypvmperformance.mbn |
| modem_b | 187324 | 51712 | 202.0 MB | — |
| bluetooth_b | 239036 | 2048 | 8.0 MB | BTFM.bin |
| abl_b | 241084 | 2048 | 8.0 MB | abl.elf |
| dsp_b | 243132 | 16384 | 64.0 MB | dspso.bin |
| keymaster_b | 259516 | 128 | 0.5 MB | keymint.mbn |
| spuservice_b | 259644 | 32 | 0.1 MB | spu_service.mbn |
| boot_b | 259676 | 24576 | 96.0 MB | boot.img |
| devcfg_b | 284252 | 64 | 0.2 MB | devcfg.mbn |
| qupfw_b | 284316 | 32 | 0.1 MB | qupv3fw.elf |
| vbmeta_b | 284348 | 32 | 0.1 MB | vbmeta.img |
| dtbo_b | 284380 | 6144 | 24.0 MB | dtbo.img |
| uefisecapp_b | 290524 | 512 | 2.0 MB | uefi_sec.mbn |
| imagefv_b | 291036 | 12288 | 48.0 MB | imagefv.elf |
| shrm_b | 303324 | 64 | 0.2 MB | shrm.elf |
| cpucp_b | 303388 | 256 | 1.0 MB | cpucp.elf |
| featenabler_b | 303644 | 32 | 0.1 MB | featenabler.mbn |
| vendor_boot_b | 303676 | 24576 | 96.0 MB | vendor_boot.img |
| qweslicstore_b | 328252 | 64 | 0.2 MB | — |
| recovery_b | 328316 | 25600 | 100.0 MB | recovery.img |
| xbl_ramdump_b | 353916 | 512 | 2.0 MB | XblRamdump.elf |
| init_boot_b | 354428 | 2048 | 8.0 MB | init_boot.img |
| cpucp_dtb_b | 356476 | 16 | 0.1 MB | cpucp_dtbs.elf |
| pvmfw_b | 356492 | 256 | 1.0 MB | pvmfw.img |
| soccp_debug_b | 356748 | 128 | 0.5 MB | sdi.mbn |
| soccp_dcd_b | 356876 | 6 | 0.0 MB | dcd.mbn |
| pdp_b | 356882 | 64 | 0.2 MB | pdp.elf |
| pdp_cdb_b | 356946 | 32 | 0.1 MB | pdp_cdb.elf |
| toolsfv | 356978 | 256 | 1.0 MB | tools.fv |
| gsort | 357234 | 4096 | 16.0 MB | — |
| storsec | 361330 | 32 | 0.1 MB | storsec.mbn |
| uefivarstore | 361362 | 128 | 0.5 MB | — |
| secdata | 361490 | 8 | 0.0 MB | — |
| mdcompress | 361498 | 5120 | 20.0 MB | — |
| connsec | 366618 | 32 | 0.1 MB | — |
| tzsc | 366650 | 32 | 0.1 MB | — |
| spunvm | 366682 | 8192 | 32.0 MB | — |
| xbl_sc_test_mode | 374874 | 16 | 0.1 MB | xbl_sc_test_mode.bin |
| xbl_sc_logs | 374890 | 32 | 0.1 MB | — |
| dpm | 374922 | 2 | 0.0 MB | — |
| last_parti | 374924 | 0 | 0.0 MB | — |
| BackupGPT | 表达式 | 5 | 0.0 MB | gpt_backup4.bin |

## LUN 5（sdf）

| 分区名 | 起始扇区 | 扇区数 | 大小 | 包内镜像 |
|---|---:|---:|---:|---|
| PrimaryGPT | 0 | 6 | 0.0 MB | gpt_main5.bin |
| ALIGN_TO_128K_2 | 6 | 26 | 0.1 MB | — |
| bk51 | 32 | 224 | 0.9 MB | — |
| modemst1 | 256 | 2048 | 8.0 MB | — |
| modemst2 | 2304 | 2048 | 8.0 MB | — |
| fsg | 4352 | 2048 | 8.0 MB | — |
| fsc | 6400 | 256 | 1.0 MB | — |
| persist | 6656 | 8192 | 32.0 MB | — |
| last_parti | 14848 | 0 | 0.0 MB | — |
| BackupGPT | 表达式 | 5 | 0.0 MB | gpt_backup5.bin |

