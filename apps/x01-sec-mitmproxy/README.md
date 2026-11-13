# x01-sec-mitmproxy

> WSL2 `wsl-x` 仓库 · `app/x01-sec-mitmproxy` 分支。真实凭据、数据、镜像不入库。

| 项 | 值 |
|---|---|
| 类型 | Docker Compose（infra `sec/mitmproxy`） |
| 状态（2026-11-13） | Exited (0)，2026-11-09 手动停 |
| 真实路径 | WSL `~/infra/sec/mitmproxy/`（`compose.yaml`、`.env`、`data/`） |
| 镜像 | `mitmproxy/mitmproxy:latest`（382 MB） |
| 端口 | `8080` 代理、`8081` mitmweb（`0.0.0.0`） |
| 数据 | `~/infra/sec/mitmproxy/data`：CA 证书、flows |
| 网络 | `x01-sec-mitmproxy_default` |
| 重启 | unless-stopped |
| 凭据 | `.env` 的 `MITMWEB_PASSWORD`，Web UI 用 `?token=` |

## 组成

- 单容器同时跑 `mitmweb`：8080 代理入口，8081 Web UI。
- `data/` 挂到 `/home/mitmproxy/.mitmproxy`，CA 证书为 `data/mitmproxy-ca-cert.cer`。
- UI 认证用 `?token=...`（mitmproxy 12 的 Bearer/token 方式），不带会 403。

## 配置

| 文件 | 说明 |
|---|---|
| `compose.yaml` | 实际启动参数（`block_global=false` 等） |
| `env.example` | Web 密码变量 |

## 启停

```bash
~/infra/bin/x01 up sec/mitmproxy
~/infra/bin/x01 down sec/mitmproxy
docker compose -f ~/infra/sec/mitmproxy/compose.yaml up -d
```

## 健康检查

```bash
docker ps -a --filter name=x01-sec-mitmproxy
curl -x http://127.0.0.1:8080 -o /dev/null -w '%{http_code}\n' http://example.com
docker logs --tail 100 x01-sec-mitmproxy
```

访问：`http://wsl.x01:8081/?token=TOKEN`；手机代理填 `wsl.x01:8080`，浏览器打开 `mitm.it` 装 CA。

## 备份 / 恢复

```bash
mkdir -p ~/infra/backup
tar czf ~/infra/backup/mitmproxy-$(date +%F).tgz -C ~/infra/sec/mitmproxy data
```

## 注意

- 8081 与 `clash-proxy-demo` 的回落端口冲突，别同时开。
- 代理监听 `0.0.0.0`，同网段可连；不用时停掉。
- CA 私钥在 `data/mitmproxy-ca.pem`，按密钥对待。

## 关联

- `main`：`system/03-容器服务清单.md`、`system/08-协调与调度.md`
- 目录总表：`main` 分支的 `apps/README.md`
