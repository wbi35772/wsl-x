# x01-net-mihomo

> WSL2 `wsl-x` 仓库 · `app/x01-net-mihomo` 分支。真实凭据、数据、镜像不入库。

| 项 | 值 |
|---|---|
| 类型 | systemd 原生服务（非容器；WSL 全部出网 + DNS） |
| 状态（2026-11-13） | **active (running)** |
| 真实路径 | WSL `~/infra/net/mihomo/`（`bin/`、`config/`、`providers/`、`rules/`、`ui/`） |
| 版本 | mihomo v1.19.33 linux amd64 with_gvisor |
| 端口 | `7890` mixed、`9090` API+UI（127.0.0.1）、`53` DNS（127.0.0.1） |
| 数据 | `config/providers/*.yaml`、`rules/`、`cache.db`、`store-selected` / `store-fake-ip` |
| 网络 | host + TUN `x01tun0`，fake-ip `198.18.0.0/16` |
| 重启 | systemd `Restart=always`，3 秒 |
| 凭据 | `config/config.yaml` 的 `secret` 与订阅 URL，不入库 |

## 组成

mihomo 负责 WSL 的所有出网与 DNS，单点：

```text
进程/容器 ──> TUN x01tun0 或 127.0.0.1:7890 ──> mihomo ──> 节点池
DNS        ──> 127.0.0.1:53 (fake-ip) ──> 按规则解析
```

配套单元：

| 单元 | 作用 |
|---|---|
| `mihomo.service` | 主服务，uid 994，带 `CAP_NET_ADMIN` |
| `mihomo-uidrule.service` | 开机写入 `ip rule uidrange 994-994 lookup main pref 8999`，防止自身流量回环进 TUN |
| `mihomo-refresh.service` | 手动/定时刷新订阅 |
| `mihomo-refresh.timer` | 原每 6h；**2026-10-29 已 disable** |
| `docker-tun-bypass` | 给 docker0 加 ip rule，容器出网绕过 TUN |

## 配置

| 文件 | 说明 |
|---|---|
| `systemd/mihomo.service` | 主服务单元 |
| `systemd/mihomo-uidrule.service` | uid 分流单元 |
| `systemd/mihomo-refresh.service` / `.timer` | 刷新单元 |
| `config/config.example.yaml` | 脱敏配置模板；provider 与密钥为占位 |

真实配置 `config/config.yaml` 含 `secret` 与节点信息，权限必须 `640 root:mihomo`。

## 启停

```bash
sudo systemctl restart mihomo-uidrule   # 先有 ip rule
sudo systemctl restart mihomo
sudo systemctl status mihomo --no-pager

sudo systemctl stop mihomo
sudo systemctl start mihomo
```

## 健康检查

```bash
ss -lntp | grep -E ':7890|:9090|:53'
curl -s 127.0.0.1:9090/version
journalctl -u mihomo -f
~/infra/net/emergency/probe.sh
```

API 需要 `Authorization: Bearer $SECRET`，secret 从 `config/config.yaml` 读。

## 刷新节点

```bash
sudo ~/infra/net/mihomo/bin/refresh-providers
```

`refresh-providers` 从 Sub-Store 拉 5 个订阅、清洗 mojibake、落盘 `providers/`，再 `PUT /providers/proxies/<name>` 热加载。下载失败不覆盖旧文件。

## 备份 / 恢复

```bash
mkdir -p ~/infra/backup
cp ~/infra/net/mihomo/config/config.yaml ~/infra/backup/mihomo-$(date +%F).yaml
tar czf ~/infra/backup/mihomo-providers-$(date +%F).tgz \
  -C ~/infra/net/mihomo/config providers
```

## 注意

- DNS 单点：mihomo 停了，WSL 域名解析全挂。应急把 `/etc/resolv.conf` 临时改为 `172.30.192.1`。
- `/etc/wsl.conf` 的 `generateResolvConf = false` 是故意的；改回来 fake-ip 会失效。
- `mihomo-refresh.timer` 已停；节点不会自动更新。
- 改配置后保持 `640 root:mihomo`，否则服务读不到。
- TUN 用 `gvisor` 栈；WSL 下 system 栈不可用。

## 关联

- `main`：`system/02-网络层与端口.md`、`system/03-容器服务清单.md`、`system/08-协调与调度.md`
- 目录总表：`main` 分支的 `apps/README.md`
