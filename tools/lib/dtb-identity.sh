#!/bin/sh
# 07: ABL 板级身份镜像
#
# 位置：dtb 阶段第 3 步
#
#   输入  $PIANO_BOOT_DTB              上一步产物
#         $PIANO_STOCK_ABL_DTB         ABL 接受的那个原厂基础 dtb
#         $PIANO_STOCK_ABL_DTB_SHA256  其 sha256（ticket 07 实测后填进 config.sh）
#   输出  $PIANO_BOOT_DTB（就地）
#
# 为什么必须做：Experiment D（liuqin）证明同一个 boot.img 里 ABL 拒收我们的主线
# DTB、却收下原厂 vendor_boot 的 dtb-02。差异是小米私有的、离线定位不到。
# 绕法是逐字节镜像 ABL 挑选路径读到的每个根身份属性（qcom,msm-id /
# qcom,board-id / compatible），让私有检查看到它确实接受过的东西。
#
# piano 的 ABL_DTB02_IDS 策略与具体取值由 ticket 07 实测决定。
#
# 由 ticket 07 实现。
set -eu

PIANO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$PIANO_ROOT/tools/lib/config.sh"
. "$PIANO_ROOT/tools/lib/common.sh"

log "07: ABL 板级身份镜像"
need_file "$PIANO_BOOT_DTB"
need_file "$PIANO_DTC"
need_file "$PIANO_STOCK_ABL_DTB"
[ -n "$PIANO_STOCK_ABL_DTB_SHA256" ] || die "config.sh 里 PIANO_STOCK_ABL_DTB_SHA256 未填（ticket 07 实测后填）"
not_implemented 07
