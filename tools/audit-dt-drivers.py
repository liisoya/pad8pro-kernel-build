#!/usr/bin/env python3
"""审计设备树里每个 compatible 是否有对应的内核驱动，以及该驱动是否被编译。

用法（内核源码根目录）：
    python3 tools/audit-dt-drivers.py <piano.dts> <kernel-src-dir> <out/.config>

为什么需要它：
  universal_defconfig 采用 allnoconfig 语义（没写到的选项 = n），
  而它漏掉了 Pad 8 Pro 的显示 / 键盘 / 充电驱动。靠人工猜 Kconfig 名
  容易错（本项目就错过三次），所以改成从编译出的 dtb 出发反查源码：
  找到真正声明 compatible 的驱动文件，再看它对应的 Kconfig 符号有没有启用。

实现要点：
  源码树里有约 4 万个 .c/.h 文件。旧实现对每个 compatible 都 rglob 一遍全树，
  复杂度是 O(compatible 数 × 文件数)，在 4 核 runner 上要跑二十几分钟。
  这里改成【只遍历一次】全树，建立 compatible -> 驱动文件 的倒排索引。

退出码恒为 0：这是报告工具，不因为「有未启用驱动」而失败。
"""
import re
import sys
from pathlib import Path

# 这些 compatible 是整机/总线/通用节点，本来就不需要独立驱动
GENERIC = {
    "qcom,sm8750", "arm,primecell", "fixed-clock", "fixed-factor-clock",
    "simple-framebuffer", "gpio-keys", "regulator-fixed", "iio-hwmon",
    "ramoops", "usb-c-connector", "syscon", "qcom,qsee-log",
    "qcom,spmi-adc5-gen3", "qcom,sm8750-tcsr-regs",
    "qcom,pm8550-rpmh-regulators", "qcom,pm8550ve-rpmh-regulators",
    "qcom,pm8550vs-rpmh-regulators", "microsoft,azure-vm-scsi",
}

# SoC 内部节点（gic、timer、smmu、rproc、pmic…）由 sm8750 平台代码无条件提供，
# 不受配置影响，逐个查驱动文件只会产出几百行噪声。审计只关注板级外设。
SKIP_PREFIX = (
    "arm,", "qcom,scci", "qcom,rmtfs", "qcom,qseccom", "qcom,geni", "qcom,ipa",
    "qcom,pasr", "qcom,secure", "qcom,hypervisor", "core,", "cache,", "cma,",
    "psci", "idle-state", "charge,", "thermal", "rpmh", "pci,", "rps,",
    "cpus", "memory@", "soc@", "reserved-memory", "hypervisor", "chosen",
    "firmware@", "aoss@", "qcom,fastrpc", "qcom,dwc3", "qcom,pcie",
)

# 只扫真正会被编译进镜像的子目录，避开 Documentation / tools 等噪声
ROOTS = ["drivers", "sound"]

# compatible 的字面形态：小写字母开头、含且仅含一个逗号，如 "novatek,nt36532"
COMPAT_RE = re.compile(r'^[a-z][a-z0-9]*,\S*$')
# 该文件确实是一份「驱动」而非随手引用字符串的证据
DRIVER_MARKER = re.compile(r'of_match_table|MODULE_DEVICE_TABLE|'
                           r'\.of_match_table|of_device_id')


def compatibles_from_dts(dts: str) -> list[str]:
    """从 dts 文本里取出所有 compatible 字符串，支持 "a", "b" 多字符串形式。"""
    out = set()
    for line in dts.split("\n"):
        if "compatible" not in line:
            continue
        for s in re.findall(r'"([^"]+)"', line):
            out.add(s.strip())
    return sorted(out)


def build_compat_index(kernel_src: Path) -> dict[str, list[str]]:
    """遍历一次源码树，建立 compatible -> 声明它的源文件 的倒排索引。"""
    index: dict[str, list[str]] = {}
    for root_name in ROOTS:
        base = kernel_src / root_name
        if not base.is_dir():
            continue
        for path in base.rglob("*.[ch]"):
            parts = path.parts
            if "test" in parts or "tests" in parts:
                continue
            try:
                txt = path.read_text(errors="ignore")
            except OSError:
                continue
            if not DRIVER_MARKER.search(txt):
                continue
            rel = str(path.relative_to(kernel_src))
            for s in re.findall(r'"([^"]+)"', txt):
                if COMPAT_RE.match(s):
                    bucket = index.setdefault(s, [])
                    if len(bucket) < 3:
                        bucket.append(rel)
    return index


def kconfig_symbols_for(kernel_src: Path, files: list[str]) -> list[str]:
    """从驱动文件所在目录的 Kconfig 反查它对应的 config 符号。

    做法：在 drivers/.../Kconfig 里找「config FOO」且 FOO 与文件名相关；
    再退一步，找 Kconfig 中 source 该文件的条目所在的上级 config 块。
    """
    syms: set[str] = set()
    for f in files:
        p = Path(f)
        stem = re.sub(r'[^a-z0-9]', '', p.stem.lower())
        for kdir in {p.parent, *p.parents[:3]}:
            kcfg = None
            for cand in ("Kconfig", "Makefile"):
                if (kernel_src / kdir / cand).is_file():
                    kcfg = kernel_src / kdir / cand
                    break
            if not kcfg:
                continue
            txt = kcfg.read_text(errors="ignore")
            # 形如：obj-$(CONFIG_X) += foo.o
            for m in re.finditer(r'obj-\$\(CONFIG_([A-Za-z0-9_]+)\)\s*\+?=\s*'
                                 rf'{re.escape(p.stem)}\.o', txt):
                syms.add("CONFIG_" + m.group(1))
            # 形如：config X_FOO
            for m in re.finditer(r'config\s+([A-Za-z0-9_]+)', txt):
                s = m.group(1)
                if stem and stem in re.sub(r'[^a-z0-9]', '', s.lower()):
                    syms.add("CONFIG_" + s)
            if syms:
                break
    return sorted(syms)


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__)
        return 1
    dts_path, kernel_src, config_path = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])

    dts = Path(dts_path).read_text(errors="ignore")
    cfg_text = config_path.read_text(errors="ignore")
    cfg = dict(re.findall(r'^(CONFIG_[A-Z0-9_]+)=([ym])', cfg_text, re.M))

    compats = [c for c in compatibles_from_dts(dts) if c not in GENERIC]
    all_compat = len(compatibles_from_dts(dts))
    board = [c for c in compats if not c.startswith(SKIP_PREFIX)]

    print(f"dtb: {dts_path}    驱动源码: {kernel_src}    配置: {config_path}")
    print(f"compatible 总数: {all_compat}    跳过 SoC 内部节点: {len(compats)-len(board)}"
          f"    需审计的板级外设: {len(board)}", flush=True)

    index = build_compat_index(kernel_src)
    print(f"已建立索引：{len(index)} 个 compatible 条目\n", flush=True)

    rows = []
    for c in board:
        files = index.get(c, [])
        if not files:
            rows.append((c, "—", "无驱动文件", ""))
            continue
        syms = kconfig_symbols_for(kernel_src, files)
        if not syms:
            # 驱动可能由别的 Kconfig 块统一编译（如 HID/MULTITOUCH/面板子菜单）
            rows.append((c, files[0], "驱动存在，符号待确认", ""))
            continue
        enabled = [f"{s}={cfg[s]}" for s in syms if s in cfg and cfg[s] in "ym"]
        if enabled:
            rows.append((c, files[0], "已启用", ",".join(enabled[:3])))
        else:
            # 该符号存在于内核 Kconfig，但没出现在 .config 里 → allnoconfig 语义下为 n
            rows.append((c, files[0], "*** 未编译 ***", ",".join(syms[:3])))

    w = max(len(r[0]) for r in rows) + 2
    print(f"{'compatible':{w}s} {'状态':16s} {'config':38s} 驱动文件")
    print("-" * 140)
    for c, f, state, cfgdesc in rows:
        print(f"{c:{w}s} {state:16s} {cfgdesc:38s} {f}")

    bad = [r for r in rows if r[2].startswith("***")]
    unknown = [r for r in rows if "待确认" in r[2]]
    nodrv = [r for r in rows if r[2] == "无驱动文件"]
    print()
    print(f"已启用: {len(rows) - len(bad) - len(unknown) - len(nodrv)}")
    print(f"未编译（会导致该功能不可用）: {len(bad)}")
    print(f"符号待确认（驱动由上级 config 编译）: {len(unknown)}")
    print(f"无驱动文件（可能为纯软件节点或共用驱动）: {len(nodrv)}")
    if bad:
        print("\n=== 未编译清单（需加入 configs/pad8pro-required.config）===")
        for c, f, _, s in bad:
            print(f"  {c}\n      候选: {s}\n      文件: {f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
