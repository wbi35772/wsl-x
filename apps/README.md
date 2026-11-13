# apps · 应用与分支总表

一个应用一个分支。单应用细节在 `app/<slug>` 分支的 `apps/<slug>/`；系统级事实在 `system/`。

| 分支 | 单元 | 容器 | 状态 | 端口 | 真实路径 |
|---|---|---|---|---|---|
| `app/goofish-hardware-sniper` | 闲鱼硬件好价监控 | `goofish-hardware-sniper` | 运行 | `8086 → 8000` | `/mnt/d/goofish-hardware-sniper` |
| `app/x01-data-postgres` | PostgreSQL 15 | `x01-data-postgres` | 停止 | `127.0.0.1:5432` | `~/infra/data/postgres` |
| `app/x01-data-mongo` | MongoDB 6 | `x01-data-mongo` | 停止 | `127.0.0.1:27017` | `~/infra/data/mongo` |
| `app/x01-dev-forgejo` | Forgejo 15 + MySQL 8.4 | `x01-dev-forgejo`、`x01-dev-forgejo-db` | 停止 | `3005`、`222` | `~/infra/dev/forgejo` |
| `app/x01-sec-mobsf` | MobSF | `x01-sec-mobsf` | 停止 | `8000` | `~/infra/sec/mobsf` |
| `app/x01-sec-mitmproxy` | mitmproxy | `x01-sec-mitmproxy` | 停止 | `8080`、`8081` | `~/infra/sec/mitmproxy` |
| `app/x01-ops-portainer` | Portainer CE | `x01-ops-portainer` | 停止 | `9443` | `~/infra/ops/portainer` |
| `app/x01-net-mihomo` | mihomo（systemd） | — | 运行 | `7890`、`9090`、`53` | `~/infra/net/mihomo` |
| `app/x01-net-substore` | Sub-Store | `x01-net-substore` | 弃用 | `3002 → 3001` | `~/infra/net/substore` |
| `app/clash-proxy-demo` | clash 实验 | `clash-proxy-demo`、`.bak` | 弃用 | `8085`、`7900`、`9093` | `~/demo/clash-proxy` |
| `app/shardx-team` | ShardX 团队服务 | `shardx-team` | 停止 | `8787` | 卷 `shardx-team-data` |
| `app/net-egress` | 出网代理 | `net-egress` | 停止 | `127.0.0.1:7891`、`9099` | `/opt/net-egress` |

## 分支内容

```text
apps/<slug>/
├─ README.md     人读：定位、端口、卷、启停、备份、真实路径、注意
├─ meta.yaml     机器可读：状态、容器、镜像、端口、卷、网络、路径、凭据键
├─ env.example   变量名 + CHANGE_ME（仅收录索引中已记录/标准镜像的键）
├─ compose.yaml  compose 单元（docker-compose 类）
├─ run.sh        docker run 单元（无 compose 的容器）
├─ systemd/      原生服务单元（systemd 类）
└─ config/       配置模板；真实配置与密钥不入库
```

## 恢复顺序

1. `mihomo` 与 DNS 正常。
2. `docker-tun-bypass` 规则存在。
3. 数据层：postgres、mongo。
4. 依赖应用：forgejo（含 MySQL）。
5. 其余按需。

细节见 [`../system/08-协调与调度.md`](../system/08-协调与调度.md)。
