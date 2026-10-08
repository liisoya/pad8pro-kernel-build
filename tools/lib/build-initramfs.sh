#!/bin/sh
# 09: initramfs 构建
#
# 位置：piano-pack.sh initramfs
#
#   输入  $PIANO_BUSYBOX        静态 busybox（arm64）
#         $PIANO_MODULES_TREE   内核模块树
#         $PIANO_MODULES_LIST   要打进 initramfs 的模块清单
#         $PIANO_FIRMWARE_LIST  要打进 initramfs 的固件映射清单
#         $PIANO_FW_STAGE       已 pull 下来的固件
#   输出  $PIANO_INITRAMFS      (cpio.gz)
#
# 两条硬约束：
#   1. 固件必须在 initramfs 里，不能放 rootfs —— request_firmware() 在
#      switch_root 之前就触发，那时 rootfs 还没挂上。
#   2. 模块清单必须含 UFS 存储模块，否则挂不上 rootfs；含 msm.ko + 面板
#      模块，否则黑屏。
#
# 预算：boot_a 只有 96 MiB（liuqin 是 192 MiB），Image gzip 后约十几 MB，
# 剩下的全给 initramfs。清单必须按这个上限裁剪，不能照搬 liuqin。
#
# 清单文件由 ticket 09（模块）/ 10·11·12（固件）填写；config.sh 只声明位置，
# 不预建空文件 —— 空清单比没有清单更容易被误当成已核实。
#
# 由 ticket 09 实现（固件映射部分依赖 10/11/12）。
set -eu

PIANO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$PIANO_ROOT/tools/lib/config.sh"
. "$PIANO_ROOT/tools/lib/common.sh"

log "09: initramfs 构建"
need_file "$PIANO_BUSYBOX"
need_dir "$PIANO_MODULES_TREE"
need_file "$PIANO_MODULES_LIST"
need_file "$PIANO_FIRMWARE_LIST"
need_dir "$PIANO_FW_STAGE"
not_implemented 09
