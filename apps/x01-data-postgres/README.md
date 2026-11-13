# x01-data-postgres

> WSL2 `wsl-x` 仓库 · `app/x01-data-postgres` 分支。真实凭据、数据、镜像不入库。

| 项 | 值 |
|---|---|
| 类型 | Docker Compose（infra `data/postgres`） |
| 状态（2026-11-13） | Exited (0)，2026-11-09 手动停 |
| 真实路径 | WSL `~/infra/data/postgres/`（`compose.yaml`、`.env`、`data/`） |
| 镜像 | `postgres:15`（633 MB） |
| 端口 | `127.0.0.1:5432 -> 5432` |
| 数据 | `~/infra/data/postgres/data`（bind，uid 999，mode 700）；库 `cx_dashboard` |
| 网络 | `x01-data-net`（172.23.0.0/16） |
| 重启 | unless-stopped |
| 凭据 | `~/infra/data/postgres/.env`；用户 `astock` |

## 组成

- 单容器 `x01-data-postgres`，`postgres:15`，只绑定宿主回环。
- 数据目录直接 bind 为 PGDATA；无命名卷。
- 健康检查 `pg_isready`；非正常关机后崩溃恢复约 4 分钟，期间拒绝连接。

## 配置

| 文件 | 说明 |
|---|---|
| `compose.yaml` | 实际 compose，环境变量全部走 `.env` |
| `env.example` | 变量名 + 非敏感默认值 |

## 启停

```bash
~/infra/bin/x01 up data/postgres
~/infra/bin/x01 down data/postgres
~/infra/bin/x01 restart data/postgres

# 等价
docker compose -f ~/infra/data/postgres/compose.yaml up -d
```

## 健康检查

```bash
docker ps -a --filter name=x01-data-postgres
docker exec x01-data-postgres pg_isready -U astock -d cx_dashboard
docker exec -it x01-data-postgres psql -U astock -d cx_dashboard
```

## 备份 / 恢复

```bash
mkdir -p ~/infra/data/postgres/backup
docker exec x01-data-postgres pg_dump -U astock -d cx_dashboard -Fc \
  > ~/infra/data/postgres/backup/cx_dashboard-$(date +%F).dump

docker exec -i x01-data-postgres pg_restore -U astock -d cx_dashboard \
  --clean --if-exists < ~/infra/data/postgres/backup/cx_dashboard-YYYY-MM-DD.dump
```

## 注意

- 手动 `docker stop` 的 `unless-stopped` 容器不会随 Docker 自启。
- 数据目录 uid 999；不要用 root 随意改权限。
- `docker compose down -v` 对 bind 数据无效，但别对 `data/` 做破坏性清理。

## 关联

- `main`：`system/03-容器服务清单.md`、`system/08-协调与调度.md`
- 目录总表：`main` 分支的 `apps/README.md`
