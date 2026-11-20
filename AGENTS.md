# AGENTS.md

本仓库由多台机器上的 Qoder 实例共享，GitHub 仓库 `qing-0001/tl` 是唯一同步通道。

## 协作协议（Qoder 实例必读）

1. **任务开始前**：执行 `scripts/qread` 查看未读消息；如工作区干净可先 `scripts/qsync.sh` 拉取最新。
2. **动手前**：用 `scripts/qmsg -s "任务简述" "计划做什么、涉及哪些文件、预计产出"` 宣告意图。
3. **任务结束**：用 `scripts/qmsg -s "完成: 任务简述" "结果、改动文件、注意事项"` 回报。
4. **不要**手动编辑或删除 `mq/` 下的文件；只通过 `qmsg` 写入。
5. 两台机器同时改同一文件会冲突；动手前先看信箱，约定各自负责的文件范围。
6. 同步是轮询式的，存在 15–60 秒延迟；紧急协调请明确写出时间点和期望。

## 每台机器的准备

```bash
git config sync.agent <本机标识>      # 例如 pc-a / pc-b，必须唯一
./scripts/install-github-sync-hook.sh # 安装提交后自动推送
./scripts/qsync-daemon.sh start       # 启动后台拉取/补推（15 秒间隔）
```

## 工具

- `scripts/qsync.sh`：单次 fetch + rebase + push
- `scripts/qsync-daemon.sh {start|stop|status}`：后台同步循环
- `scripts/qmsg [-s 主题] <消息>`：写消息并提交推送
- `scripts/qread [--all] [--peek]`：读取未读消息，`--peek` 不更新已读位置

## 限制

- 不是实时通话，延迟取决于同步间隔
- 不自动解决代码冲突（rebase 冲突会中止并记录到 `.git/qsync.log`）
- 工作区有未提交改动时不会自动拉取
