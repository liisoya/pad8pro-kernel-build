# 07: ABL 身份镜像（msm-id / board-id）

**What to build:** 让构建出的 dtb 携带与设备原厂 dtb 完全一致的 `msm-id` / `board-id`，否则 ABL 会拒绝启动。piano 的 dtbo 条目结构与 liuqin 差异巨大，识别与镜像逻辑必须重写。

**Blocked by:** 06

**Status:** ready-for-agent

- [ ] 构建出 dtb 的 `msm-id` / `board-id` 与原厂对应 dtb 逐字节一致
- [ ] 构建期有断言脚本校验该一致性
- [ ] 记录 piano dtbo 条目结构与 liuqin 的差异
