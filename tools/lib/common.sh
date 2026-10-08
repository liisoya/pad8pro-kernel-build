#!/bin/sh
# 打包脚本共用函数。所有步骤脚本 source 它，不要各自重写。
#
# 纯 POSIX sh + set -eu，不用 bash 专有语法（与 liuqin 参考实现一致）。
# 被 source 前调用方必须已设置 PIANO_ROOT。

[ -n "${PIANO_ROOT:-}" ] || {
	echo "common.sh: PIANO_ROOT 未设置（调用方需要先定位仓库根）" >&2
	exit 1
}

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

log() {
	printf '==> %s\n' "$*"
}

step() {
	printf '  -> %s\n' "$*"
}

need_file() {
	[ -r "$1" ] || die "缺少输入文件: $1"
}

need_dir() {
	[ -d "$1" ] || die "缺少输入目录: $1"
}

need_cmd() {
	command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

# 对齐的 "key: value" 行，给 --dry-run 用
kv() {
	printf '    %-26s %s\n' "$1:" "$2"
}

# 存在则带大小/条目数，否则标注缺失。--dry-run 靠它区分"已就绪"与"待产出"。
path_status() {
	if [ -r "$1" ]; then
		printf '%s (%s B)' "$1" "$(stat -c %s "$1")"
	else
		printf '%s (缺失)' "$1"
	fi
}

path_status_dir() {
	if [ -d "$1" ]; then
		printf '%s (%s 项)' "$1" "$(ls -1 "$1" 2>/dev/null | wc -l | tr -d ' ')"
	else
		printf '%s (缺失)' "$1"
	fi
}

# 校验产物不超过分区上限：$1 文件，$2 上限字节，$3 分区名
assert_fits() {
	[ -r "$1" ] || die "assert_fits: 产物不存在: $1"
	_size=$(stat -c %s "$1")
	if [ "$_size" -gt "$2" ]; then
		die "$3 装不下：$1 有 $_size B，上限 $2 B"
	fi
	step "$3 预算: $_size / $2 B"
}

# 未实现步骤的统一出口：把票号写清楚，避免后来者以为脚本坏了
not_implemented() {
	die "未实现 —— 本步骤由 ticket $1 落地，见 .scratch/piano-bringup/issues/$1-*.md"
}
