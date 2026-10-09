#!/bin/sh
# ci/build-kubuntu.sh — piano-kubuntu 一体编排（脚手架骨架）
# 职责：内核 Image/dtbs/modules -> Kubuntu 26.04 rootfs -> 镜像/boot/dtbo -> 产物 gate
# 方案：Bulid/github-actions-build-plan.md §3（工作区外文档，本仓库不含）
# 状态：脚手架——参数面已定型，各 stage 待实现（对照上游 debian-piano/scripts）
set -eu

usage() {
	cat <<EOF
usage: $0 --kernel-tree DIR --firmware-tree DIR --audioreach-topology DIR
          [--mesa-dir DIR] [--sensors-dir DIR] [--v4l2loopback DIR]
          [--jobs N] [--authorized-keys FILE] --output DIR
EOF
	exit 2
}

kernel_tree=$(pwd)/linux-piano
firmware_tree=$(pwd)/piano-firmware/firmware
topology_dir=$(pwd)/audioreach-topology
mesa_dir=
sensors_dir=
v4l2loopback_dir=
jobs=$(nproc)
authorized_keys=
output=$(pwd)/out/image

while [ $# -gt 0 ]; do
	case $1 in
	--kernel-tree)          kernel_tree=$2; shift 2 ;;
	--firmware-tree)        firmware_tree=$2; shift 2 ;;
	--audioreach-topology)  topology_dir=$2; shift 2 ;;
	--mesa-dir)             mesa_dir=$2; shift 2 ;;
	--sensors-dir)          sensors_dir=$2; shift 2 ;;
	--v4l2loopback)         v4l2loopback_dir=$2; shift 2 ;;
	--jobs)                 jobs=$2; shift 2 ;;
	--authorized-keys)      authorized_keys=$2; shift 2 ;;
	--output)               output=$2; shift 2 ;;
	*) usage ;;
	esac
done

[ -d "$kernel_tree" ] || { echo "FATAL: kernel tree missing: $kernel_tree" >&2; exit 1; }

stage_kernel() {
	# TODO: make O=out ARCH=arm64 LLVM=1 piano_defconfig + Image dtbs modules
	# modules_install 到 rootfs 树（strip 后）；vermagic 记录进 manifest
	echo "NOT-IMPLEMENTED: stage_kernel" >&2
	exit 1
}

stage_rootfs() {
	# TODO: 改造版 debian-piano/scripts/build-rootfs.sh
	# suite=questing/26.04、kde-plasma-desktop + sddm、zh_CN/Asia/Shanghai、
	# fcitx5、去 snapd、压缩工具、--mesa-dir/--sensors-dir 装入必建组件
	echo "NOT-IMPLEMENTED: stage_rootfs" >&2
	exit 1
}

stage_images() {
	# TODO: assemble-rootfs-image.sh（内容量+8GiB）、build-initramfs.sh --mode rootfs
	# （等待分区 PARTLABEL=linux-root）、build-bootimg.sh（v4/4096/gzip，<96MiB）、
	# build-dtbo.py
	echo "NOT-IMPLEMENTED: stage_images" >&2
	exit 1
}

stage_gates() {
	# TODO: COMPLETE 标记、e2fsck -fn、vermagic 逐模块校验、bootimg round-trip、
	# params provenance gate、SDDM 断言（display-manager -> sddm）
	echo "NOT-IMPLEMENTED: stage_gates" >&2
	exit 1
}

case ${1:-all} in
kernel)  stage_kernel ;;
rootfs)  stage_rootfs ;;
images)  stage_images ;;
gates)   stage_gates ;;
all)     stage_kernel && stage_rootfs && stage_images && stage_gates ;;
*)       usage ;;
esac
