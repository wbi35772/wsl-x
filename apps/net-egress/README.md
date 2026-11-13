# net-egress

> WSL2 `wsl-x` 仓库 · `app/net-egress` 分支。真实凭据、数据、镜像不入库。

| 项 | 值 |
|---|---|
| 类型 | Docker（本地出网代理，无 compose） |
| 状态（2026-11-13） | Exited (0)，`unless-stopped` |
| 真实路径 | 挂载 `/opt/net-egress`（配置与状态） |
| 镜像 | `clash-proxy-manager:latest`（本地已有） |
| 端口 | `127.0.0.1:7891` mixed、`127.0.0.1:9099` API |
| 数据 | `/opt/net-egress`：`config.yaml`、`cache.db`、`xray/` |
| 网络 | 默认 bridge，端口只绑 localhost |
| 重启 | unless-stopped |
| 凭据 | `/opt/net-egress/config.yaml` 中节点信息，不入库 |

## 组成

- 单容器，入口 `mihomo -d /root/.config/mihomo`，宿主目录 `/opt/net-egress` 挂到该路径。
- 提供独立于系统 mihomo 的第二条出网通道：`http://127.0.0.1:7891`。
- API 在 `127.0.0.1:9099`。
- 目录内另有 `xray/config.json`，来源与用途未在本仓库展开。

## 配置

| 文件 | 说明 |
|---|---|
| `run.sh` | 重建命令 |
| `config/config.example.yaml` | 脱敏配置模板，节点字段为占位 |
| `env.example` | 无环境变量（占位说明） |

## 启停

```bash
docker ps -a --filter name=net-egress
docker start net-egress
docker logs --tail 100 net-egress
```

重建：

```bash
bash apps/net-egress/run.sh
```

## 健康检查

```bash
curl -x http://127.0.0.1:7891 -I http://example.com
curl -s http://127.0.0.1:9099/version
```

## 备份 / 恢复

```bash
mkdir -p ~/infra/backup
tar czf ~/infra/backup/net-egress-$(date +%F).tgz -C /opt net-egress
```

## 注意

- 端口只绑 `127.0.0.1`，Windows 侧不能直接访问。
- 镜像无远程 tag 记录；重建前先确认 `docker image ls` 里仍有本地镜像。
- 与系统 mihomo 的 7890/9090 分开，避免端口冲突。

## 关联

- `main`：`system/02-网络层与端口.md`、`system/03-容器服务清单.md`、`system/08-协调与调度.md`
- 目录总表：`main` 分支的 `apps/README.md`
