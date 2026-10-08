#!/bin/bash
# 回归测试：ccache PATH wrapper 不得自我递归
#
# 背景：GitHub Actions 构建卡死在「配置内核」步骤 27 分钟。根因是 wrapper
# 文件名就叫 aarch64-linux-gnu-gcc 且置于 PATH 最前，它内部执行的
# `exec ccache aarch64-linux-gnu-gcc "$@"` 会按 PATH 再次命中自己，
# 形成无限 fork 递归。
#
# 这个脚本用「深度计数的假 ccache」判定递归：真跑递归会 fork 爆炸，
# 深度计数能在毫秒内给出确定性结论。
#
# 用法：bash tools/verify-ccache-wrapper.sh
# 退出码 0 = 全部通过；1 = 有用例失败

set -uo pipefail

WRAPDIR=$(mktemp -d)
FAKEBIN=$(mktemp -d)
DEPTH_FILE=$(mktemp)
trap 'rm -rf "$WRAPDIR" "$FAKEBIN" "$DEPTH_FILE"' EXIT

REAL_CC=$(command -v gcc) || { echo "找不到 gcc"; exit 1; }

# 假 ccache：每次被调用就 +1 深度，超过 3 层判定为递归
cat > "$FAKEBIN/ccache" <<EOF
#!/bin/sh
d=\$(cat "$DEPTH_FILE" 2>/dev/null || echo 0)
d=\$((d+1))
echo \$d > "$DEPTH_FILE"
if [ "\$d" -gt 3 ]; then
  echo "RECURSION" >&2
  exit 99
fi
exec "\$@"
EOF
chmod +x "$FAKEBIN/ccache"

fails=0

# $1=用例名  $2=wrapper 内部调用目标  $3=期望结论 recursion|ok
probe() {
  local name=$1 inner=$2 expect=$3
  rm -f "$DEPTH_FILE"

  # 复刻 workflow 里生成 wrapper 的方式：文件名与被调用名相同
  printf '#!/bin/sh\nexec ccache %s "$@"\n' "$inner" \
    > "$WRAPDIR/aarch64-linux-gnu-gcc"
  chmod +x "$WRAPDIR/aarch64-linux-gnu-gcc"

  local out rc depth
  out=$(PATH="$WRAPDIR:$FAKEBIN:$PATH" timeout 10 sh -c \
        'aarch64-linux-gnu-gcc --version' 2>&1)
  rc=$?
  depth=$(cat "$DEPTH_FILE" 2>/dev/null || echo 0)

  local got="ok"
  [ "$rc" = 99 ] && got="recursion"
  [ "$rc" = 124 ] && got="timeout"

  if [ "$got" = "$expect" ]; then
    printf 'PASS  %-34s depth=%s rc=%s\n' "$name" "$depth" "$rc"
  else
    printf 'FAIL  %-34s 期望=%s 实际=%s depth=%s rc=%s\n' \
      "$name" "$expect" "$got" "$depth" "$rc"
    fails=$((fails + 1))
  fi
}

echo "真实编译器: $REAL_CC"
echo

# 1. 旧版（有 bug）：wrapper 内部按名字查找 -> PATH 再次命中自己 -> 递归
probe "旧版 wrapper（按名字调用）" "aarch64-linux-gnu-gcc" recursion

# 2. 新版（修复）：wrapper 内部用绝对路径 -> 一次命中，深度为 1
probe "新版 wrapper（绝对路径）" "$REAL_CC" ok

# 3. 回归护栏：显式绝对路径 + 同名 wrapper 组合下仍必须是 ok
probe "绝对路径 + 同名 wrapper" "$REAL_CC" ok

echo
if [ "$fails" -eq 0 ]; then
  echo "全部通过：wrapper 无递归，workflow 中的写法正确"
else
  echo "有 $fails 个用例失败"
fi
exit "$fails"
