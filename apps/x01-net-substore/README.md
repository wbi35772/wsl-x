# x01-net-substore

> WSL2 `wsl-x` 仓库 · `app/x01-net-substore` 分支。真实凭据、数据、镜像不入库。

| 项 | 值 |
|---|---|
| 类型 | Docker Compose（infra `net/substore`，订阅转换） |
| 状态（2026-11-13） | 弃用（2026-10-29），`restart: no` |
| 真实路径 | WSL `~/infra/net/substore/`（`compose.yaml`、`.env`、`data/`） |
| 镜像 | `xream/sub-store:latest` |
| 端口 | `3002 -> 3001`（宿主 3001 被 OpenChamber 占用） |
| 数据 | `~/infra/net/substore/data`（`sub-store.json` 与订阅缓存） |
| 网络 | `x01-net-substore_default` |
| 重启 | no（永不自动起） |
| 凭据 | `.env` 的 `SUB_STORE_FRONTEND_BACKEND_PATH` 随机后台路径 |

## 组成

- 单容器 `x01-net-substore`，把 5 个上游订阅聚合为 ClashMeta YAML。
- 曾是 mihomo 的订阅上游；mihomo 现在直接读本地 `providers/*.yaml`，Sub-Store 已停用。
- 同步 cron 改为 `0 0 31 2 *`（2 月 31 日，永不触发）。
- 前端路径是随机串，形如 `/CHANGE_ME`，不要改成根路径。

## 配置

| 文件 | 说明 |
|---|---|
| `compose.yaml` | 实际 compose（含停用注释） |
| `env.example` | 后台路径与可选代理变量 |

## 启停

```bash
# 确认状态
docker ps -a --filter name=substore

# 临时启动
~/infra/bin/x01 up net/substore

# 停止
~/infra/bin/x01 down net/substore
```

## 健康检查

```bash
docker logs -f x01-net-substore
BE=$(grep -m1 '^SUB_STORE_FRONTEND_BACKEND_PATH=' ~/infra/net/substore/.env | cut -d= -f2)
curl -s "http://127.0.0.1:3002$BE/api/subs" | jq '.[].name'
```

前端：`http://127.0.0.1:3002$BE`。

## 备份 / 恢复

```bash
mkdir -p ~/infra/backup
tar czf ~/infra/backup/substore-$(date +%F).tgz -C ~/infra/net/substore data
```

恢复 `data/` + `.env` 即可，后台路径不变。

## 注意

- 已弃用，不要恢复自动同步；需要节点时用 `~/infra/net/mihomo/bin/refresh-providers`。
- 上游订阅失败时 `GET /download/<name>` 会 500 或报 TLS 错误，重试即可。
- 输出节点名可能含双重编码的控制符，喂给 mihomo 前必须过 `sanitize-provider`。

## 关联

- `main`：`system/02-网络层与端口.md`、`system/03-容器服务清单.md`、`system/08-协调与调度.md`
- 目录总表：`main` 分支的 `apps/README.md`
