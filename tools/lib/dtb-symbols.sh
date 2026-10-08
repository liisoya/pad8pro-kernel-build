#!/bin/sh
# 08: __symbols__ 注入 + overlay 汇聚 sink
#
# 位置：dtb 阶段第 4 步（最后一步）
#
#   输入  $PIANO_BOOT_DTB        上一步产物
#         $PIANO_STOCK_DTBO_DIR  原厂 dtbo 条目（导出符号用）
#         $PIANO_STOCK_BASE_DIR  原厂基础 dtb（补充符号来源）
#   输出  $PIANO_BOOT_DTB（就地）
#
# 为什么必须做：ABL 总会往 boot.img 携带的 DTB 上套原厂 DTBO overlay，
# 套不上就**直接中止启动**。主线 DTB 缺 __symbols__ 节点所以套不上。
# 加上该节点 + 一个惰性 sink，让 overlay 能套上并把写入导向 sink。
#
# 不能只按一个条目导出符号：ABL 挑哪一条不由我们决定，且 ufdt 可能套多条。
# 也不只按 DTBO 表导出：liuqin 实测还有个不存在于任何可枚举分区的运行时
# Gunyah RM DTBO，只导出 DTBO 并集的 base 会在它引用的第一个 label 上崩。
# 所以符号并集要把原厂 base DTB 也一起种子进去。
#
# 注意：piano 的 DTBO 条目数与结构都与 liuqin 不同（不是 44 条），
# 识别逻辑必须重写，不能照搬 liuqin 的硬编码计数断言。
#
# 由 ticket 08 实现。
set -eu

PIANO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$PIANO_ROOT/tools/lib/config.sh"
. "$PIANO_ROOT/tools/lib/common.sh"

log "08: __symbols__ 注入"
need_file "$PIANO_BOOT_DTB"
need_file "$PIANO_DTC"
need_dir "$PIANO_STOCK_DTBO_DIR"
need_dir "$PIANO_STOCK_BASE_DIR"
not_implemented 08
