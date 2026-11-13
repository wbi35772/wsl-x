# x01-ops-portainer

> WSL2 `wsl-x` 仓库 · `app/x01-ops-portainer` 分支。真实凭据、数据、镜像不入库。

| 项 | 值 |
|---|---|
| 类型 | Docker Compose（infra `ops/portainer`） |
| 状态（2026-11-13） | Exited (2)，2026-11-09 手动停；停止时退出码 2 正常 |
| 真实路径 | WSL `~/infra/ops/portainer/`（`compose.yaml`、`data/`） |
| 镜像 | `portainer/portainer-ce:latest`（201 MB） |
| 端口 | `9443 -> 9443`（HTTPS） |
| 数据 | `~/infra/ops/portainer/data`（Portainer 自身 DB） |
| 网络 | `x01-ops-portainer_default` |
| 重启 | unless-stopped |
| 凭据 | 首次访问设置 admin 密码；无 `.env` |

## 组成

- 单容器 Portainer CE，挂载 `/var/run/docker.sock`，可管理全部容器。
- 启动参数 `--no-setup-token`，跳过首次初始化令牌。
- 仅在本机使用；`docker.sock` 等同于宿主机 root 能力。

## 配置

| 文件 | 说明 |
|---|---|
| `compose.yaml` | 实际 compose |
| `env.example` | 无环境变量（占位说明） |

## 启停

```bash
~/infra/bin/x01 up ops/portainer
~/infra/bin/x01 down ops/portainer
docker compose -f ~/infra/ops/portainer/compose.yaml up -d
```

## 健康检查

```bash
docker ps -a --filter name=x01-ops-portainer
docker logs --tail 100 x01-ops-portainer
```

访问：`https://wsl.x01:9443/`。

## 备份 / 恢复

```bash
mkdir -p ~/infra/backup
tar czf ~/infra/backup/portainer-$(date +%F).tgz -C ~/infra/ops/portainer data
```

## 注意

- 退出码 2 出现在停止时，不是崩溃。
- 不要把它暴露到不可信网络；`docker.sock` 权限过高。

## 关联

- `main`：`system/03-容器服务清单.md`、`system/08-协调与调度.md`
- 目录总表：`main` 分支的 `apps/README.md`
