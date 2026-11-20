#!/usr/bin/env bash
# 与 GitHub 单次同步：fetch -> (工作区干净时) rebase -> push
# 远程/分支读取 git config sync.remote / sync.branch（默认 origin / master）
set -uo pipefail
LC_ALL=C

top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "请在 Git 仓库内运行" >&2; exit 1; }
cd "$top"
gitdir=$(git rev-parse --absolute-git-dir)
log="$gitdir/qsync.log"

remote=$(git config --get sync.remote 2>/dev/null || true); [ -n "$remote" ] || remote=origin
branch=$(git config --get sync.branch 2>/dev/null || true); [ -n "$branch" ] || branch=master

log() { echo "[$(date '+%F %T')] $*" >>"$log"; }

exec 9>"$gitdir/github-sync.lock"
flock -n 9 || { log "skip: locked"; exit 0; }

[ -n "$(git symbolic-ref -q HEAD)" ] || { log "skip: detached HEAD"; exit 0; }
cur=$(git symbolic-ref --short -q HEAD)
if [ "$cur" != "$branch" ]; then
  log "skip: on $cur"
  echo "当前在 $cur 分支（同步目标 $branch），已跳过" >&2
  exit 0
fi
git remote get-url "$remote" >/dev/null 2>&1 || { log "error: no remote $remote"; exit 1; }

if ! timeout 60 git fetch --quiet "$remote" 2>>"$log"; then
  log "fetch failed"
  echo "fetch 失败，详见 $log" >&2
  exit 1
fi

dirty=0
git diff --quiet || dirty=1
git diff --cached --quiet || dirty=1
if [ "$dirty" -eq 0 ] && [ -n "$(git ls-files -o --exclude-standard | head -n1)" ]; then dirty=1; fi

behind=$(git rev-list --count "HEAD..$remote/$branch" 2>/dev/null || echo 0)
ahead=$(git rev-list --count "$remote/$branch..HEAD" 2>/dev/null || echo 0)

if [ "$behind" -gt 0 ]; then
  if [ "$dirty" -eq 1 ]; then
    log "behind $behind but dirty: skip rebase"
    echo "远程有新提交（落后 $behind），工作区有未提交改动，已跳过拉取" >&2
  else
    if git rebase --quiet "$remote/$branch" 2>>"$log"; then
      log "rebased onto $remote/$branch"
      ahead=$(git rev-list --count "$remote/$branch..HEAD")
    else
      git rebase --abort 2>/dev/null
      log "rebase conflict: aborted"
      echo "rebase 冲突，已中止，请手动处理" >&2
      exit 1
    fi
  fi
fi

if [ "$ahead" -gt 0 ]; then
  if timeout 60 git push --quiet "$remote" "HEAD:$branch" 2>>"$log"; then
    log "pushed $ahead commit(s)"
  else
    log "push failed"
    echo "push 失败，详见 $log" >&2
    exit 1
  fi
fi
exit 0
