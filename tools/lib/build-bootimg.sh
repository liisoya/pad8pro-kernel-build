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
need_cmd python3
need_cmd cmp

# 1. gzip 重压内核。-n 不写时间戳与文件名，保证同样的 Image 两次打出的
#    字节完全一致（ticket 04 验收要与输入 Image 逐字节回比）。
step "gzip -n -9 重压内核 -> $PIANO_IMAGE_GZ"
gzip -n -9 -c "$PIANO_IMAGE" > "$PIANO_IMAGE_GZ"

# 2. mkbootimg。所有参数来自 config.sh（ADR-0001），命令行留空 ——
#    cmdline 走 dtb 的 /chosen/bootargs（ticket 06），写进 header 会被
#    dtb bootargs 覆盖，两处不一致时 ABL 行为未定义。
step "mkbootimg: header v$BOOT_HEADER_VERSION, pagesize $BOOT_PAGESIZE"
python3 "$PIANO_MKBOOTIMG_DIR/mkbootimg.py" \
	--header_version "$BOOT_HEADER_VERSION" \
	--pagesize "$BOOT_PAGESIZE" \
	--base "$BOOT_BASE" \
	--kernel_offset "$BOOT_KERNEL_OFFSET" \
	--ramdisk_offset "$BOOT_RAMDISK_OFFSET" \
	--tags_offset "$BOOT_TAGS_OFFSET" \
	--dtb_offset "$BOOT_DTB_OFFSET" \
	--kernel "$PIANO_IMAGE_GZ" \
	--ramdisk "$PIANO_INITRAMFS" \
	--dtb "$PIANO_BOOT_DTB" \
	--cmdline "${BOOT_HEADER_CMDLINE:-}" \
	--output "$PIANO_BOOTIMG"
assert_fits "$PIANO_BOOTIMG" "$PIANO_BOOT_PARTITION_BYTES" "$PIANO_BOOT_SLOT_A"

# 3. unpack 回验。打包脚本自己证明自己：反解出的信息与载荷必须全部
#    对得上输入，任何一条不符就失败，不把「以为对了」的镜像交出去。
step "unpack_bootimg 反解回验"
VERIFY_DIR=$PIANO_BUILD_OUT/bootimg-verify
rm -rf "$VERIFY_DIR"
mkdir -p "$VERIFY_DIR"
python3 "$PIANO_MKBOOTIMG_DIR/unpack_bootimg.py" \
	--boot_img "$PIANO_BOOTIMG" --out "$VERIFY_DIR" > "$PIANO_BOOTIMG_INFO"
cat "$PIANO_BOOTIMG_INFO"
echo

grep -qx "boot image header version: $BOOT_HEADER_VERSION" "$PIANO_BOOTIMG_INFO" \
	|| die "header 版本不是 $BOOT_HEADER_VERSION（见 ADR-0001）"
grep -qx "page size: $BOOT_PAGESIZE" "$PIANO_BOOTIMG_INFO" \
	|| die "pagesize 不是 $BOOT_PAGESIZE"
# cmdline 必须为空（对照 dtc 后的 dtb，command line args 行冒号后无内容）
if grep "^command line args:" "$PIANO_BOOTIMG_INFO" | grep -vq "^command line args: *$"; then
	die "header cmdline 非空 —— cmdline 必须走 dtb /chosen/bootargs（ticket 06）"
fi

# 载荷回比：反解出的 kernel 是 gzip 流，解压后必须与输入 Image 逐字节一致
step "回比 kernel payload"
[ -r "$VERIFY_DIR/kernel" ] || die "unpack 未产出 kernel"
[ -r "$VERIFY_DIR/dtb" ] || die "unpack 未产出 dtb"
TMP_KERNEL=$PIANO_BUILD_OUT/.verify-kernel
gzip -dc "$VERIFY_DIR/kernel" > "$TMP_KERNEL"
cmp -s "$TMP_KERNEL" "$PIANO_IMAGE" || {
	rm -f "$TMP_KERNEL"
	die "kernel payload 与输入 Image 不一致"
}
rm -f "$TMP_KERNEL"
cmp -s "$VERIFY_DIR/dtb" "$PIANO_BOOT_DTB" || die "dtb 与输入 boot dtb 不一致"

step "boot.img: $PIANO_BOOTIMG ($(stat -c %s "$PIANO_BOOTIMG") B)"
