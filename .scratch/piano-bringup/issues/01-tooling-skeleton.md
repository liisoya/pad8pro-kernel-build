# 01: 打包工具骨架与共享配置

**What to build:** 一个 piano 专用的打包入口：从 liuqin 参考实现移植 boot 打包与 initramfs 构建脚本，把所有机器相关参数（SoC 名、分区名、固件目录、模块清单来源、内核/dtb 输入路径）收敛到单一配置文件。跑 `--dry-run` 能打印解析后的全部输入路径与清单，**不需要真机、不需要内核产物**。

这是让后续每张票"只填一块"的 prefactor：先把"改哪里"从散落的脚本里抽到一个配置入口。

**Blocked by:** None (can start immediately)

**Status:** done (2026-10-08)

- [x] 存在单一配置入口，声明 SoC、分区名、固件目录、模块清单来源 —— `tools/lib/config.sh`（141 行，全部参数可溯源到 notes/ 与 ADR）
- [x] 打包入口支持 `--dry-run`：打印解析后的输入/输出路径，退出码 0 —— `tools/piano-pack.sh` 实测通过（2026-10-08，本机 exit=0，全部路径正确解析）
- [x] 五个子步骤各有明确落点：boot 打包 / initramfs 构建 / dtb overlay 合并 / 身份 id 镜像 / `__symbols__` 注入 —— `tools/lib/{build-bootimg,build-initramfs,dtb-overlay,dtb-cmdline,dtb-identity,dtb-symbols}.sh`，均以 need_file/need_dir 前置校验 + `not_implemented` 声明契约，不假装能跑
- [x] 骨架运行不依赖真机与内核产物 —— dry-run 对缺失路径仅标注（缺失），不失败
