#!/usr/bin/env bash
# 安装 post-commit hook：提交后自动把指定分支推送到 GitHub 镜像仓库。
# 用法（在仓库内任意位置执行）：
#   ./scripts/install-github-sync-hook.sh
# 可用环境变量覆盖：
#   GITHUB_OWNER=qing-0001 GITHUB_REPO=tl SYNC_REMOTE=origin SYNC_BRANCH=master
#   GITHUB_REMOTE_URL=git@github.com:qing-0001/tl.git   # 完整覆盖远程地址
set -euo pipefail

OWNER="${GITHUB_OWNER:-qing-0001}"
REPO="${GITHUB_REPO:-tl}"
REMOTE="${SYNC_REMOTE:-origin}"
BRANCH="${SYNC_BRANCH:-master}"
URL="${GITHUB_REMOTE_URL:-git@github.com:$OWNER/$REPO.git}"

top=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "错误：请在 Git 仓库内运行本脚本" >&2
  exit 1
}
cd "$top"
gitdir=$(git rev-parse --git-dir)

if git remote get-url "$REMOTE" >/dev/null 2>&1; then
  current=$(git remote get-url "$REMOTE")
  if [ "$current" != "$URL" ]; then
    echo "警告：远程 $REMOTE 已存在且地址不同，保持原样：$current"
    echo "      如需改用 $URL，请手动执行：git remote set-url $REMOTE $URL"
  fi
else
  git remote add "$REMOTE" "$URL"
  echo "已添加远程 $REMOTE -> $URL"
fi

git config sync.remote "$REMOTE"
git config sync.branch "$BRANCH"

hook="$gitdir/hooks/post-commit"
if [ -f "$hook" ] && ! grep -q "install-github-sync-hook.sh 安装" "$hook"; then
  backup="$hook.bak.$(date +%Y%m%d%H%M%S)"
  mv "$hook" "$backup"
  echo "已备份原有 hook：$backup"
fi

cat > "$hook" <<'HOOK'
#!/bin/sh
# 由 scripts/install-github-sync-hook.sh 安装，提交后自动同步到镜像远程。
# 配置：git config sync.remote / sync.branch（默认 origin / master）

gitdir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
remote=$(git config --get sync.remote 2>/dev/null) || remote=origin
branch=$(git config --get sync.branch 2>/dev/null) || branch=master
[ "$(git symbolic-ref --short -q HEAD)" = "$branch" ] || exit 0
git remote get-url "$remote" >/dev/null 2>&1 || exit 0

(
  exec 9>"$gitdir/github-sync.lock"
  flock -n 9 || exit 0
  echo "[$(date '+%F %T')] push $(git rev-parse --short HEAD)"
  GIT_TERMINAL_PROMPT=0 timeout 60 git push --quiet "$remote" "$branch"
  rc=$?
  echo "[$(date '+%F %T')] push exit=$rc"
) >>"$gitdir/github-sync.log" 2>&1 &

exit 0
HOOK
chmod +x "$hook"
echo "已安装 hook：$hook（同步 $REMOTE/$BRANCH，日志 $gitdir/github-sync.log）"

ssh_out=$(timeout 15 ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)
if printf '%s' "$ssh_out" | grep -q "successfully authenticated"; then
  echo "GitHub SSH 认证：OK"
else
  echo "警告：GitHub SSH 认证失败。请把公钥添加到 https://github.com/settings/keys" >&2
  echo "      查看公钥：cat ~/.ssh/id_ed25519.pub" >&2
fi
