#!/bin/sh
# 06: 内核 cmdline 注入 /chosen/bootargs
#
# 位置：dtb 阶段第 2 步
#
#   输入  $PIANO_BOOT_DTB   上一步产物
#   输出  $PIANO_BOOT_DTB（就地）
#
# 关键约束：ABL 从 DTB 的 /chosen 读 cmdline，**不读 boot header**。
# 因此 $BOOT_HEADER_CMDLINE 默认为空，命令行只能写在这里。
# ABL 会把自己约 800 字符拼到该属性尾部，我们的内容排在前、先被解析。
#
# 高通主线早期启动必需：clk_ignore_unused pd_ignore_unused rootwait
# （liuqin 还带了 earlycon=simplefb 用于点亮前的唯一可见通道，piano 待定）
#
# 由 ticket 06 实现。
set -eu

PIANO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
. "$PIANO_ROOT/tools/lib/config.sh"
. "$PIANO_ROOT/tools/lib/common.sh"

log "06: /chosen/bootargs 注入"
need_file "$PIANO_BOOT_DTB"
need_file "$PIANO_DTC"
not_implemented 06
