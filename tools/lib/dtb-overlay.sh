#!/bin/sh
# 05: 面板 overlay 合并
#
# 位置：dtb 阶段第 1 步（piano-pack.sh dtb / all）
#
#   输入  $PIANO_KERNEL_DTB      主线 sm8750-xiaomi-piano.dtb
#         $PIANO_STOCK_DTBO_DIR  原厂 dtbo 解包条目（人工抓取，ticket 03）
#         $PIANO_FDTOVERLAY      内核构建树自带的 fdtoverlay
#   输出  $PIANO_BOOT_DTB
#
#   待定  piano 原厂 dtbo 里用的是 BOE 还是 CSOT 条目，决定合哪条 overlay
#         以及用哪版触控固件（两版 .bin 都实存）—— 见 IMPLEMENTATION-PLAN §6.2
#
# 由 ticket 05 实现。骨架阶段只声明契约，不假装能跑。
set -eu

PIANO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$PIANO_ROOT/tools/lib/config.sh"
. "$PIANO_ROOT/tools/lib/common.sh"

log "05: 面板 overlay 合并"
need_file "$PIANO_KERNEL_DTB"
need_file "$PIANO_FDTOVERLAY"
need_dir "$PIANO_STOCK_DTBO_DIR"
not_implemented 05
