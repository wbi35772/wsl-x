# x01-dev-forgejo

> WSL2 `wsl-x` 仓库 · `app/x01-dev-forgejo` 分支。真实凭据、数据、镜像不入库。

| 项 | 值 |
|---|---|
| 类型 | Docker Compose（Forgejo + MySQL，两个容器） |
| 状态（2026-11-13） | Exited (0)，2026-11-09 手动停；`-db` 同步停止 |
| 真实路径 | WSL `~/infra/dev/forgejo/`（`compose.yaml`、`.env`、`conf/app.ini`、`data/`） |
| 镜像 | `codeberg.org/forgejo/forgejo:15.0.3`、`mysql:8.4.11` |
| 端口 | `3005 -> 3000` HTTP、`222 -> 22` SSH；MySQL 仅内部 `3306` |
| 数据 | `data/forgejo`（uid 1000）、`data/db`（uid 999）、`conf/app.ini` |
| 网络 | `x01-dev-forgejo_default` |
| 重启 | unless-stopped |
| 凭据 | `.env` 的 MySQL root；`conf/app.ini` 的 DB 密码、`SECRET_KEY`、`INTERNAL_TOKEN`、`LFS_JWT_SECRET`、`JWT_SECRET` |

## 组成

两个容器属于同一 compose 项目，放同一分支：

| 容器 | 角色 | 说明 |
|---|---|---|
| `x01-dev-forgejo` | app | Forgejo 15，HTTP 3000 / SSH 22 |
| `x01-dev-forgejo-db` | db | MySQL 8.4，仅容器网络 3306 |

`app.ini` 里 `[database] HOST = mysql:3306`，服务名必须保持 `mysql`；`ROOT_URL` 当前写死 WSL IP，Windows 侧应使用 `http://wsl.x01:3005/`。

## 配置

| 文件 | 说明 |
|---|---|
| `compose.yaml` | 实际 compose，MySQL 健康后启动 Forgejo |
| `conf/app.ini.example` | 从真实配置脱敏；密钥字段全部 `CHANGE_ME` |
| `env.example` | MySQL root 密码变量 |

## 启停

```bash
~/infra/bin/x01 up dev/forgejo
~/infra/bin/x01 down dev/forgejo
~/infra/bin/x01 restart dev/forgejo

docker compose -f ~/infra/dev/forgejo/compose.yaml up -d
```

## 健康检查

```bash
docker ps -a --filter name=x01-dev-forgejo
docker logs --tail 100 x01-dev-forgejo
docker exec -it x01-dev-forgejo-db mysql -uroot -p -e 'show databases'
```

访问：`http://wsl.x01:3005/`；SSH：`ssh -p 222 git@wsl.x01`。

## 备份 / 恢复

```bash
# 一致性优先：停应用，打包数据与配置，再启
~/infra/bin/x01 down dev/forgejo
mkdir -p ~/infra/backup
tar czf ~/infra/backup/forgejo-$(date +%F).tgz \
  -C ~/infra/dev/forgejo data conf .env
~/infra/bin/x01 up dev/forgejo
```

在线替代：`forgejo dump -c /data/gitea/conf/app.ini -f /data/backup/forgejo.zip`（DB 名以 app.ini 为准）。

## 注意

- `data/forgejo` uid 1000、`data/db` uid 999；不要整目录 `chown root`。
- 已镜像私有仓库 `xiaoming/wsl-infra`，镜像内 `.env` 全为 `CHANGE_ME`。
- 改 `ROOT_URL` 后需重启；否则页面资源 404。

## 关联

- `main`：`system/03-容器服务清单.md`、`system/08-协调与调度.md`
- 目录总表：`main` 分支的 `apps/README.md`
