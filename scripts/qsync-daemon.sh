#!/usr/bin/env bash
# 同步守护进程：周期性调用 qsync.sh
# 用法: qsync-daemon.sh {start|stop|status}   间隔秒数: QSYNC_INTERVAL（默认 15）
set -uo pipefail

self_dir=$(cd "$(dirname "$0")" && pwd)
top=$(git -C "$self_dir" rev-parse --show-toplevel 2>/dev/null) || { echo "脚本必须在仓库的 scripts/ 目录内" >&2; exit 1; }
gitdir=$(git -C "$top" rev-parse --absolute-git-dir)
pidfile="$gitdir/qsync-daemon.pid"
logfile="$gitdir/qsync-daemon.log"
interval=${QSYNC_INTERVAL:-15}
cmd=${1:-run}

running() { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }

case "$cmd" in
  start)
    if running; then echo "已在运行 (pid $(cat "$pidfile"))"; exit 0; fi
    nohup "$0" run >>"$logfile" 2>&1 &
    echo $! >"$pidfile"
    echo "已启动 pid $!，间隔 ${interval}s，日志 $logfile"
    ;;
  stop)
    if running; then
      pid=$(cat "$pidfile")
      kill "$pid" 2>/dev/null
      for _ in $(seq 1 25); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.2
      done
      kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
      rm -f "$pidfile"
      echo "已停止"
    else
      rm -f "$pidfile"
      echo "未在运行"
    fi
    ;;
  status)
    if running; then echo "运行中 (pid $(cat "$pidfile"))"; else echo "未运行"; fi
    ;;
  run)
    echo $$ >"$pidfile"
    cleanup() { rm -f "$pidfile"; }
    trap cleanup EXIT
    trap 'exit 0' INT TERM
    echo "[$(date '+%F %T')] daemon start pid $$ interval ${interval}s"
    while :; do
      "$self_dir/qsync.sh" || true
      if [ -f "$logfile" ] && [ "$(stat -c%s "$logfile" 2>/dev/null || echo 0)" -gt 1048576 ]; then
        : >"$logfile"
      fi
      sleep "$interval"
    done
    ;;
  *)
    echo "用法: $0 {start|stop|status}" >&2
    exit 2
    ;;
esac
