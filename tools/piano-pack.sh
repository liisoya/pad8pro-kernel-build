#!/bin/sh
# piano 打包入口（ticket 01）
#
# 用法：
#   tools/piano-pack.sh                  同 --dry-run（默认最安全）
#   tools/piano-pack.sh --dry-run        打印解析后的输入/输出路径与清单，退出码 0
#   tools/piano-pack.sh all              依次跑 dtb → initramfs → bootimg
#   tools/piano-pack.sh dtb|initramfs|bootimg
#
# 设计意图：把所有机器相关参数收敛到 tools/lib/config.sh，让后续每张票"只填一块"，
# 而不是在每个脚本顶部考古 ${VAR:-default}。
# --dry-run 不要求内核产物、原厂解包产物或真机存在，因此可以在干净的 CI 上跑。

set -eu

PIANO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$PIANO_ROOT/tools/lib/config.sh"
. "$PIANO_ROOT/tools/lib/common.sh"

LIB=$PIANO_ROOT/tools/lib

usage() {
	cat <<EOF
用法: $(basename "$0") [--dry-run] [all|dtb|initramfs|bootimg]

不带参数等同于 --dry-run。

步骤与落点（dtb 阶段按此顺序串行）：
  dtb        $LIB/dtb-overlay.sh       面板 overlay 合并    (ticket 05)
             $LIB/dtb-cmdline.sh       /chosen/bootargs     (ticket 06)
             $LIB/dtb-identity.sh      ABL 身份 id 镜像      (ticket 07)
             $LIB/dtb-symbols.sh       __symbols__ 注入      (ticket 08)
  initramfs  $LIB/build-initramfs.sh                        (ticket 09)
  bootimg    $LIB/build-bootimg.sh                          (ticket 04)

环境变量覆盖：
  KERNEL_OUT   内核构建输出目录   默认 $PIANO_KERNEL_OUT
  BUILD_OUT    打包输出目录       默认 $PIANO_BUILD_OUT
  STOCK_DIR    原厂解包产物目录   默认 $PIANO_STOCK_DIR
EOF
}

dry_run() {
	log "设备身份"
	kv device "$PIANO_DEVICE"
	kv soc "$PIANO_SOC"
	kv dtb "$PIANO_DTB_NAME"

	log "输入 · 内核产物"
	kv kernel_out "$(path_status_dir "$PIANO_KERNEL_OUT")"
	kv Image "$(path_status "$PIANO_IMAGE")"
	kv kernel_dtb "$(path_status "$PIANO_KERNEL_DTB")"
	kv modules_tree "$(path_status_dir "$PIANO_MODULES_TREE")"
	kv dtc "$(path_status "$PIANO_DTC")"
	kv fdtoverlay "$(path_status "$PIANO_FDTOVERLAY")"

	log "输入 · 原厂解包产物（人工抓取，ticket 03）"
	kv stock_dir "$(path_status_dir "$PIANO_STOCK_DIR")"
	kv stock_dtbo "$(path_status_dir "$PIANO_STOCK_DTBO_DIR")"
	kv stock_base "$(path_status_dir "$PIANO_STOCK_BASE_DIR")"
	kv stock_abl_dtb "$(path_status "$PIANO_STOCK_ABL_DTB")"
	kv stock_abl_sha256 "${PIANO_STOCK_ABL_DTB_SHA256:-<未填，ticket 07>}"

	log "输入 · 固件 stage"
	kv fw_stage "$(path_status_dir "$PIANO_FW_STAGE")"

	log "清单来源"
	kv modules_list "$(path_status "$PIANO_MODULES_LIST")"
	kv firmware_list "$(path_status "$PIANO_FIRMWARE_LIST")"

	log "第三方工具"
	kv mkbootimg "$(path_status_dir "$PIANO_MKBOOTIMG_DIR")"
	kv busybox "$(path_status "$PIANO_BUSYBOX")"

	log "boot 镜像契约（ADR-0001）"
	kv header_version "$BOOT_HEADER_VERSION"
	kv pagesize "$BOOT_PAGESIZE"
	kv base "$BOOT_BASE"
	kv kernel_offset "$BOOT_KERNEL_OFFSET"
	kv ramdisk_offset "$BOOT_RAMDISK_OFFSET"
	kv tags_offset "$BOOT_TAGS_OFFSET"
	kv dtb_offset "$BOOT_DTB_OFFSET"
	kv header_cmdline "${BOOT_HEADER_CMDLINE:-<空，cmdline 走 dtb /chosen/bootargs>}"

	log "分区预算（硬上限）"
	kv boot_partition "$PIANO_BOOT_PARTITION_BYTES B ($PIANO_BOOT_SLOT_A)"
	kv dtbo_partition "$PIANO_DTBO_PARTITION_BYTES B ($PIANO_DTBO_SLOT_A)"
	kv block_size "$PIANO_BLOCK_SIZE ($PIANO_USERDATA_PARTITION)"
	kv persist "$PIANO_PERSIST_BYTES B ($PIANO_PERSIST_PARTITION，不可恢复)"
	kv bt_partition "$PIANO_BT_PARTITION"

	log "输出"
	kv build_out "$PIANO_BUILD_OUT"
	kv boot_dtb "$PIANO_BOOT_DTB"
	kv initramfs "$PIANO_INITRAMFS"
	kv bootimg "$PIANO_BOOTIMG"

	exit 0
}

run_stage() {
	mkdir -p "$PIANO_BUILD_OUT"
	case $1 in
	dtb)
		"$LIB/dtb-overlay.sh"
		"$LIB/dtb-cmdline.sh"
		"$LIB/dtb-identity.sh"
		"$LIB/dtb-symbols.sh"
		;;
	initramfs)
		"$LIB/build-initramfs.sh"
		;;
	bootimg)
		"$LIB/build-bootimg.sh"
		;;
	all)
		run_stage dtb
		run_stage initramfs
		run_stage bootimg
		;;
	*)
		die "未知阶段: $1"
		;;
	esac
}

main() {
	_dry=0
	_stage=
	for _a in "$@"; do
		case $_a in
		--dry-run) _dry=1 ;;
		all | dtb | initramfs | bootimg) _stage=$_a ;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			usage >&2
			exit 2
			;;
		esac
	done

	# 骨架阶段：没明确给阶段就只做 dry-run，不碰任何产物
	if [ "$_dry" = 1 ] || [ -z "$_stage" ]; then
		dry_run
	fi

	run_stage "$_stage"
}

main "$@"
