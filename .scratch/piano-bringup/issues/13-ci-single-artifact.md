# 13: CI 产出单一可刷 artifact

**What to build:** 一次 CI 构建产出 `boot.img` + `initramfs` + `Image` + `dtb` + `modules`，合并为单个 artifact，含校验清单与构建信息。这是阶段 1 的收口：产物下载下来就是可刷的。

**Blocked by:** 04, 08, 09, 10, 11, 12

**Status:** ready-for-agent

- [ ] CI 一次运行产出全部五类产物
- [ ] 合并为单个 artifact，含 SHA256SUMS 与 build-info
- [ ] 下载后 `boot.img` 可反解、dtb 含 `/chosen/bootargs`
