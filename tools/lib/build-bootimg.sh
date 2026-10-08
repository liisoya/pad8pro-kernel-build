#!/bin/sh
# 04: boot.img 打包
#
# 位置：piano-pack.sh bootimg（最后一步）
#
#   输入  $PIANO_IMAGE            裸 Image → gzip -n -9 → $PIANO_IMAGE_GZ
#         $PIANO_BOOT_DTB         dtb 阶段产物
#         $PIANO_INITRAMFS        initramfs 阶段产物
#         $PIANO_MKBOOTIMG_DIR    aosp-mkbootimg（tools/local/ 不入库，CI 现场拉取）
#   输出  $PIANO_BOOTIMG
#         $PIANO_BOOTIMG_INFO     unpack_bootimg 的 info
#
# 参数全部来自 config.sh（ADR-0001）：header v2、pagesize 4096、
# kernel/ramdisk/tags/dtb offset。cmdline 走 dtb，header 留空。
#
# 验证手法照抄 liuqin：解包后逐字节 cmp 回比 kernel / dtb / ramdisk，
# 再断言 header 版本、cmdline、各段大小与 dtb 加载地址。
# 三趟 dtc 重写（fdtoverlay / 身份镜像 / 符号注入）之后，
# 只能断言结果，不能假设中间没掉东西。
#
# 最后按 $PIANO_BOOT_PARTITION_BYTES 校验上限。
#
# header v2 是否真被 SM8750 的 ABL 接受，由 ticket 14 真机裁决；
# 不接受则改 v4（IMPLEMENTATION-PLAN §6.1）。
#
# 由 ticket 04 实现。
set -eu

PIANO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$PIANO_ROOT/tools/lib/config.sh"
. "$PIANO_ROOT/tools/lib/common.sh"

log "04: boot.img 打包"
need_file "$PIANO_IMAGE"
need_file "$PIANO_BOOT_DTB"
need_file "$PIANO_INITRAMFS"
need_file "$PIANO_MKBOOTIMG_DIR/mkbootimg.py"
need_file "$PIANO_MKBOOTIMG_DIR/unpack_bootimg.py"
need_cmd gzip
not_implemented 04
