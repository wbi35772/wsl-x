# clash-proxy-demo

> WSL2 `wsl-x` 仓库 · `app/clash-proxy-demo` 分支。真实凭据、数据、镜像不入库。

| 项 | 值 |
|---|---|
| 类型 | Docker（host 网络，实验/演示，含 `.bak` 副本） |
| 状态（2026-11-13） | Exited (137)，10 天前；`restart: no` |
| 真实路径 | WSL `~/demo/clash-proxy/`（`config/`） |
| 镜像 | `clash-proxy-manager:latest`（593 MB） |
| 端口 | host：`8085` 面板、`7900` mixed、`9093` API、`10001+` SOCKS5（重建后 `30000+`） |
| 数据 | `~/demo/clash-proxy/config`（订阅、缓存、规则备份） |
| 网络 | `network_mode: host` |
| 重启 | no |
| 凭据 | `config/` 内订阅与密钥，不入库 |

## 组成

- `clash-proxy-demo` 与旧副本 `clash-proxy-demo.bak` 使用同一镜像，放同一分支。
- 容器内 mihomo 读取 `/root/.config/mihomo`，宿主挂载 `~/demo/clash-proxy/config`。
- 面板占用 8085；重建时漏掉 `DASHBOARD_PORT=8085` 会回落到 8081，与 mitmweb 冲突并退出。
- `restart: no`，本来就不会自动起。

## 配置

| 文件 | 说明 |
|---|---|
| `run.sh` | 重建命令；环境变量有默认值 |
| `config/README.md` | 目录内容说明；真实 config 不入库 |

## 启停

```bash
docker ps -a --filter name=clash-proxy-demo
docker start clash-proxy-demo
docker logs --tail 100 clash-proxy-demo
```

重建：

```bash
cd ~/demo/clash-proxy
bash apps/clash-proxy-demo/run.sh
```

## 健康检查

```bash
curl -s http://127.0.0.1:8085/ >/dev/null && echo panel-ok
curl -x http://127.0.0.1:7900 -I http://example.com
curl -s http://127.0.0.1:9093/version
```

## 备份 / 恢复

```bash
mkdir -p ~/infra/backup
tar czf ~/infra/backup/clash-proxy-demo-$(date +%F).tgz -C ~/demo/clash-proxy config
```

## 清理

```bash
docker rm -f clash-proxy-demo clash-proxy-demo.bak
docker rmi clash-proxy-manager:latest
```

## 注意

- host 网络 + 100 个 SOCKS5 端口，不要和 mihomo 同时占同名端口。
- 8081 与 mitmweb 冲突；两者不要同时开。
- `.bak` 是旧副本，清理时一起删。

## 关联

- `main`：`system/02-网络层与端口.md`、`system/03-容器服务清单.md`、`system/08-协调与调度.md`
- 目录总表：`main` 分支的 `apps/README.md`
