# 04: boot.img 组装

**What to build:** 用已产出的内核 `Image` 与 dtb 打出一个能被 `unpack_bootimg` 反解、且 header 版本与页大小正确的 `boot.img`。这是整条链路的第一个可验证产物，**不需要真机**。

必须在本票内解决一个已知矛盾：`CONTEXT.md` 称 ZSTD 的 `Image` 需要 header **v4+**，而实现方案称先把内核 gzip 重压后走 **v2**（liuqin 的做法）。两者不可能同时成立 —— 要么 gzip 重压后 v2，要么直接用 ZSTD 走 v4。选定一个并记录依据（真机不接受时回退到另一个，见 14）。

**Blocked by:** 01

**Status:** done (2026-10-08)

- [x] `boot.img` 生成，`unpack_bootimg` 反解出的 pagesize = 4096 ——
      本机实测 EXIT=0，`page size: 4096`、`boot image header version: 2`，
      产物 `out/piano/boot-piano.img` 13,746,176 B < boot_a 预算 100,663,296 B
- [x] header 版本已确定 —— **v2 + `gzip -n -9` 重压**。依据：ADR-0001 §决策.1
      （重压后 ZSTD 内核不再要求 v4）+ 参考实现实测 `--header_version 2`；
      与 `CONTEXT.md` / `notes/BUILD-STATUS.md` 的早期 v4+ 说法矛盾已按 §6.1
      回填修正。**真机裁决在 ticket 14**：ABL 不接受 v2 则整体改 v4
      （`tools/lib/config.sh` BOOT_HEADER_VERSION 单点可改）。
- [x] 反解出的 kernel payload 与输入 `Image` 可校验一致 —— 脚本内置
      `gzip -dc` 解压后 `cmp -s` 逐字节回比 + dtb 回比，实测通过
      （"回比 kernel payload" 无 die）
- [x] boot header 内 cmdline 为空 —— 反解 `command line args:` 行为空，
      脚本断言非空即 die（命令行走 dtb /chosen/bootargs，见 06）

**验证上下文（2026-10-08）**：输入用真实内核 `Image`（CI 产物）+ 内核树编出的
原始 piano dtb 顶替 `$PIANO_BOOT_DTB`（dtb overlay 管线是 ticket 05–08，未落地）
+ 165 B 占位 initramfs。即：本票只验收**打包力学与回验机制**，dtb/ramdisk 的
真实内容正确性由 05–09 各票验收。
