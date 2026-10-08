# 06: cmdline 注入（/chosen/bootargs）

**What to build:** 把内核命令行写进 dtb 的 `/chosen/bootargs`，**而不是** boot header —— ABL 只从 dtb 的 `/chosen` 读命令，这是 liuqin 踩过的坑。

**Blocked by:** 05

**Status:** ready-for-agent

- [ ] 合并后 dtb 的 `/chosen/bootargs` 含 `clk_ignore_unused pd_ignore_unused rootwait`
- [ ] `fdtget` 可反查确认
- [ ] console / earlycon 参数按 piano 实测调整并记录
