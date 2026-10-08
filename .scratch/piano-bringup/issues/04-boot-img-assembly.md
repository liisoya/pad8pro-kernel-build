# 04: boot.img 组装

**What to build:** 用已产出的内核 `Image` 与 dtb 打出一个能被 `unpack_bootimg` 反解、且 header 版本与页大小正确的 `boot.img`。这是整条链路的第一个可验证产物，**不需要真机**。

必须在本票内解决一个已知矛盾：`CONTEXT.md` 称 ZSTD 的 `Image` 需要 header **v4+**，而实现方案称先把内核 gzip 重压后走 **v2**（liuqin 的做法）。两者不可能同时成立 —— 要么 gzip 重压后 v2，要么直接用 ZSTD 走 v4。选定一个并记录依据（真机不接受时回退到另一个，见 14）。

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] `boot.img` 生成，`unpack_bootimg` 反解出的 pagesize = 4096
- [ ] header 版本已确定（v2 + gzip 重压，或 v4 + ZSTD），并记录选择依据
- [ ] 反解出的 kernel payload 与输入 `Image` 可校验一致
- [ ] boot header 内 cmdline 为空（命令行走 dtb，见 06）
