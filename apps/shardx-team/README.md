# shardx-team

> WSL2 `wsl-x` 仓库 · `app/shardx-team` 分支。真实凭据、数据、镜像不入库。

| 项 | 值 |
|---|---|
| 类型 | Docker（团队浏览器服务端，无 compose） |
| 状态（2026-11-13） | Exited (0) |
| 真实路径 | 无源码目录记录；数据在 Docker 卷 `shardx-team-data` |
| 镜像 | `ghcr.io/proxyshard/shardbrowser-team-server:latest`（52.6 MB） |
| 端口 | `8787 -> 8787` |
| 数据 | 命名卷 `shardx-team-data` -> `/data` |
| 网络 | 默认 bridge |
| 重启 | 未设置（不自动起） |
| 凭据 | 容器环境变量 `SHARDBROWSER_TEAM_*`，真实值不入库 |

## 组成

- 单容器，入口 `/usr/local/bin/shardbrowser-team-server`。
- 数据只在命名卷 `shardx-team-data`；删容器可以，删卷会丢数据。
- 无 compose，原参数靠 `docker inspect` 回看；本分支用 `run.sh` 固化。

## 配置

| 文件 | 说明 |
|---|---|
| `run.sh` | 重建命令；团队名/公开地址为占位 |
| `env.example` | 环境变量键 |

## 启停

```bash
docker ps -a --filter name=shardx-team
docker start shardx-team
docker logs --tail 100 shardx-team
```

重建：

```bash
bash apps/shardx-team/run.sh
```

## 健康检查

```bash
docker ps --filter name=shardx-team
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8787/
```

## 备份 / 恢复

```bash
mkdir -p ~/infra/backup
docker run --rm -v shardx-team-data:/data -v ~/infra/backup:/backup alpine \
  tar czf /backup/shardx-team-data-$(date +%F).tgz -C /data .
```

## 注意

- 没有源码目录；升级镜像前先备份卷。
- 数据卷是唯一持久化内容。
- 原容器未设置 restart policy，按需手动启动。

## 关联

- `main`：`system/02-网络层与端口.md`、`system/03-容器服务清单.md`、`system/08-协调与调度.md`
- 目录总表：`main` 分支的 `apps/README.md`
