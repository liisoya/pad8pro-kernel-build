#!/usr/bin/env bash
# push-via-api.sh —— 在 PUT 被网络拦截的环境里提交文件到 GitHub
#
# 为什么需要它：本机直连 github.com 时，git push 与 REST 的 PUT 一律返回
# 500，而 POST / PATCH 正常。Git Data API 的 blobs / trees / commits / refs
# 恰好只需 POST（建引用）与 PATCH（移动 main），因此可以绕过限制。
#
# 用法：push-via-api.sh <repo> <branch> <file>...
set -euo pipefail

REPO="${1:?用法: push-via-api.sh <owner/repo> <branch> <file>...}"
BRANCH="${2:?}"
shift 2

API=https://api.github.com
TOKEN=$(gh auth token)
hdr=(-H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json")

# 1. 当前分支指针
PARENT=$(curl -sS "${hdr[@]}" "$API/repos/$REPO/git/ref/heads/$BRANCH" | jq -r .object.sha)
BASE_TREE=$(curl -sS "${hdr[@]}" "$API/repos/$REPO/git/commits/$PARENT" | jq -r .tree.sha)
echo "parent=$PARENT base_tree=$BASE_TREE"

# 2. 为每个文件建 blob
entries=()
for f in "$@"; do
  SHA=$(jq -n --rawfile c "$f" '{content:$c, encoding:"utf-8"}' \
        | curl -sS -X POST "${hdr[@]}" --data @- "$API/repos/$REPO/git/blobs" \
        | jq -r .sha)
  printf '  blob %-45s %s\n' "$f" "${SHA:0:10}"
  entries+=("$(jq -n --arg p "$f" --arg s "$SHA" \
              '{path:$p, mode:"100644", type:"blob", sha:$s}')")
done

# 3. 建 tree（base_tree 为底，未列出的文件保持原样）
TREE=$(printf '%s\n' "${entries[@]}" \
       | jq -s --arg b "$BASE_TREE" '{base_tree:$b, tree:.}' \
       | curl -sS -X POST "${hdr[@]}" --data @- "$API/repos/$REPO/git/trees" \
       | jq -r .sha)
echo "tree=$TREE"

# 4. 建 commit（提交信息可用环境变量 GH_MSG 覆盖，避免所有提交共用一句）
MSG="${GH_MSG:-update: $(printf '%s ' "$@")}"
COMMIT=$(jq -n --arg m "$MSG" \
             --arg t "$TREE" --arg p "$PARENT" \
             '{message:$m, tree:$t, parents:[$p]}' \
          | curl -sS -X POST "${hdr[@]}" --data @- "$API/repos/$REPO/git/commits" \
          | jq -r .sha)
echo "commit=$COMMIT"

# 5. 移动分支指针
curl -sS -X PATCH "${hdr[@]}" -d "{\"sha\":\"$COMMIT\"}" \
     "$API/repos/$REPO/git/refs/heads/$BRANCH" | jq -r '.object.sha'
echo "done -> https://github.com/$REPO/commit/$COMMIT"
