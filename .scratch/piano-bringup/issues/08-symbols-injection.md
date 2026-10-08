# 08: __symbols__ 注入与 ABL overlay 抑制

**What to build:** 向 dtb 注入 `__symbols__` 与 sink 节点，并设置抑制标志，使 ABL 不再对已合并的 dtb 二次套 overlay。这是"缺了就中止启动"的硬要求。

**Blocked by:** 07

**Status:** ready-for-agent

- [ ] dtb 含 `__symbols__`
- [ ] ABL overlay 抑制标志已设置
- [ ] 反解确认不会发生二次 overlay 应用
