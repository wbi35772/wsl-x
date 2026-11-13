# x01-data-mongo

> WSL2 `wsl-x` 仓库 · `app/x01-data-mongo` 分支。真实凭据、数据、镜像不入库。

| 项 | 值 |
|---|---|
| 类型 | Docker Compose（infra `data/mongo`） |
| 状态（2026-11-13） | Exited (0)，2026-11-09 手动停 |
| 真实路径 | WSL `~/infra/data/mongo/`（`compose.yaml`、`.env`、`data/`） |
| 镜像 | `mongo:6`（1.1 GB） |
| 端口 | `127.0.0.1:27017 -> 27017` |
| 数据 | `~/infra/data/mongo/data/db`（bind，uid 999）；`/data/configdb` 未持久化 |
| 网络 | `x01-data-net`（172.23.0.0/16） |
| 重启 | unless-stopped |
| 凭据 | `~/infra/data/mongo/.env`；`mongoadmin`，`authSource=admin` |

## 组成

- 单容器 `x01-data-mongo`，`mongo:6`，只绑定宿主回环。
- compose 仅挂载 `./data/db`；`/data/configdb` 用容器内匿名卷，重建即丢（无业务数据）。
- 与 Postgres 共用外部网络 `x01-data-net`，容器内可用 `x01-data-mongo:27017`。

## 配置

| 文件 | 说明 |
|---|---|
| `compose.yaml` | 实际 compose |
| `env.example` | 根账号变量名 |

## 启停

```bash
~/infra/bin/x01 up data/mongo
~/infra/bin/x01 down data/mongo
~/infra/bin/x01 restart data/mongo

docker compose -f ~/infra/data/mongo/compose.yaml up -d
```

## 健康检查

```bash
docker ps -a --filter name=x01-data-mongo
docker exec -it x01-data-mongo mongosh -u mongoadmin --authenticationDatabase admin
docker logs --tail 100 x01-data-mongo
```

## 备份 / 恢复

```bash
mkdir -p ~/infra/data/mongo/backup
docker exec -it x01-data-mongo mongodump -u mongoadmin \
  --authenticationDatabase admin --archive --gzip \
  > ~/infra/data/mongo/backup/mongo-$(date +%F).gz

docker exec -i x01-data-mongo mongorestore -u mongoadmin \
  --authenticationDatabase admin --archive --gzip --drop \
  < ~/infra/data/mongo/backup/mongo-YYYY-MM-DD.gz
```

## 注意

- 数据目录 uid 999；迁移时连 `data/` 一起搬。
- `docker compose down -v` 会删匿名卷；本 compose 的业务数据在 bind 目录，仍在。
- 手动停止不会随 Docker 自启。

## 关联

- `main`：`system/03-容器服务清单.md`、`system/08-协调与调度.md`
- 目录总表：`main` 分支的 `apps/README.md`
