# piano 打包的【单一配置入口】
#
# 为什么需要它：liuqin 的脚本把机器相关参数（SoC 名、dtb 路径、固件目录、
# ramdisk 路径、分区大小）散落在每个脚本顶部的 ${VAR:-default} 里。搬到 piano
# 时这些默认值全部要改，散落写法会让「改哪里」变成考古题。这里一次性收敛，
# 各步骤脚本只引用变量，不再自带默认值。
#
# 改这些值 = 改机器事实。每个值必须能指到下面某个来源，不要凭感觉调：
#   分区尺寸 → notes/PARTITION-LAYOUT.md（双源核对）+ notes/DEVICE-FACTS.md（真机实测）
#   固件路径 → notes/DEVICE-FACTS.md §固件分布（TWRP 实测）
#   boot 参数 → docs/adr/0001
#
# 本文件只声明变量，不含逻辑，也不做存在性检查（那是 common.sh 的事）。
# 被 source 前调用方必须已设置 PIANO_ROOT。

[ -n "${PIANO_ROOT:-}" ] || {
	echo "config.sh: PIANO_ROOT 未设置（调用方需要先定位仓库根）" >&2
	exit 1
}

# ---------------------------------------------------------------------------
# 设备身份
# ---------------------------------------------------------------------------
PIANO_DEVICE=piano
PIANO_SOC=sm8750
PIANO_DTB_NAME=sm8750-xiaomi-piano.dtb
# 内核构建树内的相对路径（CI 把内核 checkout 到子目录 linux/）
PIANO_IMAGE_RELPATH=arch/arm64/boot/Image
PIANO_DTB_RELPATH=arch/arm64/boot/dts/qcom/sm8750-xiaomi-piano.dtb

# ---------------------------------------------------------------------------
# 分区（字节。boot/dtbo 是硬上限，打包必须校验）
# ---------------------------------------------------------------------------
PIANO_BOOT_SLOT_A=boot_a
PIANO_BOOT_SLOT_B=boot_b
PIANO_DTBO_SLOT_A=dtbo_a
PIANO_VENDOR_BOOT_SLOT_A=vendor_boot_a
PIANO_USERDATA_PARTITION=sda34
PIANO_PERSIST_PARTITION=persist
PIANO_BT_PARTITION=bluetooth_a

# 注意：piano 的 boot_a 是 96 MiB，liuqin 是 192 MiB —— 预算只有一半。
# Image 裸片 48 MB，gzip 后约十几 MB，剩下的全给 initramfs，
# ticket 09 必须按这个上限裁剪模块与固件，不能照搬 liuqin 的清单。
PIANO_BOOT_PARTITION_BYTES=100663296
PIANO_DTBO_PARTITION_BYTES=25165824
PIANO_USERDATA_BYTES=247954649088
PIANO_PERSIST_BYTES=33554432

# sda 逻辑块大小（真机 blockdev --getbsz 实测）
PIANO_BLOCK_SIZE=4096

# ---------------------------------------------------------------------------
# boot 镜像契约（ADR-0001；参数值取自 liuqin 参考实现实测）
#
# header 版本是当前最大的未决项：ADR-0001 定 v2，CONTEXT.md / BUILD-STATUS.md
# 曾写 v4+（已回填修正）。SM8750 的 ABL 是否接受 v2 尚未真机验证，
# ticket 04 产出、ticket 14 验证；不接受则整体改 v4。
# ---------------------------------------------------------------------------
BOOT_HEADER_VERSION=2
BOOT_PAGESIZE=4096
BOOT_BASE=0x00000000
BOOT_KERNEL_OFFSET=0x00008000
BOOT_RAMDISK_OFFSET=0x01000000
BOOT_TAGS_OFFSET=0x00000100
BOOT_DTB_OFFSET=0x01f00000
# 内核 cmdline 不写 header，走 dtb 的 /chosen/bootargs（ticket 06）
BOOT_HEADER_CMDLINE=

# ---------------------------------------------------------------------------
# 内核产物输入
# ---------------------------------------------------------------------------
PIANO_KERNEL_OUT=${KERNEL_OUT:-$PIANO_ROOT/out/kernel}
PIANO_IMAGE=$PIANO_KERNEL_OUT/$PIANO_IMAGE_RELPATH
PIANO_KERNEL_DTB=$PIANO_KERNEL_OUT/$PIANO_DTB_RELPATH
PIANO_MODULES_TREE=$PIANO_KERNEL_OUT/lib/modules
# dtc / fdtoverlay 来自内核构建树（用内核自己的版本，避免主机 dtc 行为差异）
PIANO_DTC=$PIANO_KERNEL_OUT/scripts/dtc/dtc
PIANO_FDTOVERLAY=$PIANO_KERNEL_OUT/scripts/dtc/fdtoverlay

# ---------------------------------------------------------------------------
# 原厂解包产物（人工从设备抓取，ticket 03 一并 dd）
# 放 tools/local/ 下：该目录已被 .gitignore 忽略，大二进制不入库
# ---------------------------------------------------------------------------
PIANO_STOCK_DIR=${STOCK_DIR:-$PIANO_ROOT/tools/local/stock/piano}
PIANO_STOCK_DTBO_DIR=$PIANO_STOCK_DIR/dtbo
PIANO_STOCK_BASE_DIR=$PIANO_STOCK_DIR/vendor_boot/dtbs
# 身份镜像源：ABL 接受的那个基础 dtb（对应 liuqin 的 dtb-02.dtb）。
# piano 具体是哪一个、以及其 sha256，ticket 07 实测后填这里。
PIANO_STOCK_ABL_DTB=${STOCK_ABL_DTB:-$PIANO_STOCK_BASE_DIR/dtb-02.dtb}
PIANO_STOCK_ABL_DTB_SHA256=${STOCK_ABL_DTB_SHA256:-}

# ---------------------------------------------------------------------------
# 固件来源
#
# 从设备 pull 出来后落到 $PIANO_FW_STAGE 下的分类子目录；构建脚本只认 stage
# 目录，不直接读设备路径 —— 否则 CI 无法复现。
# ---------------------------------------------------------------------------
PIANO_FW_STAGE=$PIANO_ROOT/firmware/piano
FW_SUBDIR_GPU=gpu
FW_SUBDIR_WLAN=wlan
FW_SUBDIR_WLAN_PERSIST=wlan-persist
FW_SUBDIR_TOUCH=touch
FW_SUBDIR_KEYBOARD=keyboard
FW_SUBDIR_BT=bluetooth
FW_SUBDIR_DSP=dsp
FW_SUBDIR_AUDIO=audio

# 设备侧原始路径（真机实测，仅供人工抓取时对照；脚本不读）
#   GPU     /vendor/firmware/gen80600_gmu.bin
#   触控    /odm/firmware/novatek_nt36532_piano_fw_{boe,csot}.bin
#   键盘    /odm/firmware/MCU_Upgrade.bin                (83,436 B, Nanosic 803)
#   Wi-Fi   /vendor/firmware/wlan/qca_cld/peach/
#   Wi-Fi   /vendor/etc/wifi/peach/WCNSS_qcom_cfg.ini
#   MAC     /mnt/vendor/persist/wlan/wlan_mac.bin        (本机专属，不可跨设备)
#   BT      bluetooth_a 分区（vfat）→ brhbtfw20.mbn / gngbtfw20.mbn

# ---------------------------------------------------------------------------
# 清单来源
# 两个清单文件由 ticket 09（模块）与 ticket 10/11/12（固件）填写。
# ticket 01 只声明位置，不预先创建 —— 空清单比没有清单更容易被误当成已核实。
# ---------------------------------------------------------------------------
PIANO_MODULES_LIST=$PIANO_ROOT/configs/piano-initramfs-modules.txt
PIANO_FIRMWARE_LIST=$PIANO_ROOT/configs/piano-initramfs-firmware.txt

# ---------------------------------------------------------------------------
# 第三方工具（tools/local/ 不入库，CI 需现场拉取，见 tools/fetch-aosp-mkbootimg.sh）
# ---------------------------------------------------------------------------
PIANO_MKBOOTIMG_DIR=${MKBOOTIMG_DIR:-$PIANO_ROOT/tools/local/aosp-mkbootimg}
PIANO_BUSYBOX=${BUSYBOX:-$PIANO_ROOT/tools/local/busybox-arm64}

# ---------------------------------------------------------------------------
# 输出
# ---------------------------------------------------------------------------
PIANO_BUILD_OUT=${BUILD_OUT:-$PIANO_ROOT/out/piano}
PIANO_BOOT_DTB=$PIANO_BUILD_OUT/sm8750-xiaomi-piano-boot.dtb
PIANO_BOOT_DTS=$PIANO_BUILD_OUT/sm8750-xiaomi-piano-boot.dts
PIANO_IMAGE_GZ=$PIANO_BUILD_OUT/Image.gz
PIANO_INITRAMFS=$PIANO_BUILD_OUT/initramfs-piano.cpio.gz
PIANO_BOOTIMG=$PIANO_BUILD_OUT/boot-piano.img
PIANO_BOOTIMG_INFO=$PIANO_BUILD_OUT/boot-piano.info
