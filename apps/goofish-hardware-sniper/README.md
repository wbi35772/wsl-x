# goofish-hardware-sniper

> WSL2 `wsl-x` 仓库 · `app/goofish-hardware-sniper` 分支。真实凭据、数据、镜像不入库。

| 项 | 值 |
|---|---|
| 类型 | Docker Compose 单容器应用（闲鱼硬件好价监控） |
| 状态（2026-11-13） | **Up (healthy)**，当前唯一在跑的容器 |
| 真实路径 | WSL `/mnt/d/goofish-hardware-sniper`；Windows `D:\goofish-hardware-sniper` |
| 镜像 | `goofish-hardware-sniper:local`（本项目构建，1.64 GB） |
| 端口 | `8086 -> 8000`（`0.0.0.0`） |
| 数据 | `data/app.sqlite3`、`state/`、`accounts/`、`logs/`、`images/`、`jsonl/`、`price_history/` |
| 网络 | `goofish-hardware-sniper_default` |
| 重启 | unless-stopped |
| 凭据 | 项目 `.env`：`WEB_PASSWORD`、`OPENAI_API_KEY` 等，不入库 |

## 组成

- 单容器 `goofish-hardware-sniper`，`python -m src.app`，入口用 `tini`。
- SQLite 主库 `data/app.sqlite3`；`config.json` 定义任务，运行时状态以 SQLite / Web UI 为准。
- 浏览器登录态在 `accounts/` 与 `state/`；掉登录时借助 Windows Chrome CDP `9223`。
- 端口：宿主 `8086` -> 容器 `8000`，健康检查 `/health`。

## 配置

| 文件 | 说明 |
|---|---|
| `docker-compose.yaml` | 实际 compose；`build: .` + 本地镜像 |
| `env.example` | 变量名清单，值统一 `CHANGE_ME` |
| `config.example.json` | 任务定义样例（关键词、价格区间、cron、账号文件） |

关键环境变量：`OPENAI_*`、`WEB_*`、`PROXY_*`、`TASK_FAILURE_*`、`*_TOKEN/URL` 推送。完整键见 `env.example`。

## 启停

```bash
cd /mnt/d/goofish-hardware-sniper
docker compose up -d --build        # 改代码后重建
docker start goofish-hardware-sniper
docker restart goofish-hardware-sniper
docker stop goofish-hardware-sniper
```

## 健康检查

```bash
docker ps --filter name=goofish-hardware-sniper --format '{{.Status}}\t{{.Ports}}'
curl -s http://127.0.0.1:8086/health
docker logs --tail 200 -f goofish-hardware-sniper
```

## 备份 / 恢复

```bash
# SQLite 热备
python3 - <<'PY'
import sqlite3
src = sqlite3.connect('/mnt/d/goofish-hardware-sniper/data/app.sqlite3')
dst = sqlite3.connect('/mnt/d/goofish-hardware-sniper/data/app.backup.sqlite3')
src.backup(dst); dst.close(); src.close()
PY

# 登录态与账号（不含 .env）
tar czf ~/backup/goofish-state-$(date +%F).tgz \
  -C /mnt/d/goofish-hardware-sniper state accounts
```

## 注意

- 宿主端口 **8086**，容器内 **8000**，两个数字都会出现。
- 首次/掉登录：先跑 `scripts/start_chrome_debug.ps1`（9223），容器通过 `host.docker.internal:9223` 连接；`deploy_wsl.sh` 会注入 `HOST_GATEWAY_IP`。
- AI 并发固定 1（`AI_ANALYSIS_CONCURRENCY=1`），任务分钟错开 1–7，抖动 0–180 秒。
- 连续 3 次失败由 `FailureGuard` 暂停 24 小时，可在 UI 重新启用。
- 依赖 DNS；mihomo 未起时域名解析失败，先修网络层。

## 关联

- `main`：`system/03-容器服务清单.md`、`system/08-协调与调度.md`
- 目录总表：`main` 分支的 `apps/README.md`
