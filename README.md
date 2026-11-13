# wsl-x

> WSL2 系统的协调、调度与容器/应用配置记录。
> 私有仓库；不含真实凭据、镜像、数据与 `vhdx`。

## 分支模型

| 分支 | 作用 | 内容 |
|---|---|---|
| `main` | 系统级协调与调度 | `system/` 系统档案（01–08）+ `apps/README.md` 总表 |
| `app/<slug>` | 一个可部署单元 | `apps/<slug>/README.md`、`meta.yaml`、`env.example` |

命名规则：

- `main` 只放**跨应用**的系统事实：启动链、依赖顺序、端口分配、重启策略、定时任务、故障恢复。
- `app/<slug>`：一个应用一个分支。`slug` 用主容器名或项目名，小写 kebab-case。
- **同一项目的多个容器/模块放一个分支**。例：`x01-dev-forgejo` 分支同时记录 `x01-dev-forgejo` 与 `x01-dev-forgejo-db`，不拆子分支。
- 非容器系统服务也归 `app/`，用 `meta.yaml` 的 `kind: systemd` 标记（例：`x01-net-mihomo`）。
- 弃用/实验应用保留在 `app/` 下，用 `status: deprecated|experiment` 标记，不另建前缀。
- 分支最多两级（`app/<slug>`）；版本用 tag（`app-<slug>-v1`），不再嵌套 `app/<slug>/v2`。

## 分支地图

| 分支 | 单元 | 容器 | 当前状态 | 备注 |
|---|---|---|---|---|
| `main` | 系统协调/调度 | — | 现行 | 01–08 + 总表 |
| `app/goofish-hardware-sniper` | 闲鱼硬件监控 | `goofish-hardware-sniper` | 运行 | `8086 → 8000` |
| `app/x01-data-postgres` | PostgreSQL 15 | `x01-data-postgres` | 停止 | 库 `cx_dashboard` |
| `app/x01-data-mongo` | MongoDB 6 | `x01-data-mongo` | 停止 | `127.0.0.1:27017` |
| `app/x01-dev-forgejo` | Forgejo + MySQL | `x01-dev-forgejo`、`x01-dev-forgejo-db` | 停止 | 同分支含 DB |
| `app/x01-sec-mobsf` | MobSF | `x01-sec-mobsf` | 停止 | `8000` |
| `app/x01-sec-mitmproxy` | mitmproxy | `x01-sec-mitmproxy` | 停止 | `8080`/`8081` |
| `app/x01-ops-portainer` | Portainer CE | `x01-ops-portainer` | 停止 | `9443` |
| `app/x01-net-mihomo` | mihomo | systemd（非容器） | 运行 | `7890`/`9090`/`53` |
| `app/x01-net-substore` | Sub-Store | `x01-net-substore` | 弃用 | `3002 → 3001` |
| `app/clash-proxy-demo` | clash 实验 | `clash-proxy-demo`、`.bak` | 弃用 | host 网络 |
| `app/shardx-team` | ShardX 团队服务 | `shardx-team` | 停止 | `8787` |
| `app/net-egress` | 出网代理 | `net-egress` | 停止 | `127.0.0.1:7891`、`9099` |

## 使用

```bash
git clone https://github.com/wbi35772/wsl-x.git
cd wsl-x

git checkout app/goofish-hardware-sniper
git checkout main
```

恢复/启停顺序见 [`system/08-协调与调度.md`](system/08-协调与调度.md)。每个应用分支的 `meta.yaml` 是机器可读记录，`README.md` 是人读的运维卡片。

## 内容约定

- `system/` 是 WSL2 系统的**参数快照**，跨应用；修改端口、路径、依赖后回写这里。
- `apps/` 只维护目录与分支映射；单应用细节在各自分支的 `apps/<slug>/`。
- `env.example` 只写变量名和 `CHANGE_ME`，不写真实值。
- 真实配置在 WSL：`~/infra/*/.env`、`~/infra/net/mihomo/config/config.yaml`、`/mnt/d/goofish-hardware-sniper/.env`。

## 状态快照（2026-11-13）

- 唯一运行容器：`goofish-hardware-sniper`；x01 七个 2026-11-09 手动停止。
- 网络层：systemd `mihomo`，mixed `7890`、DNS `53`、API `9090`、TUN `x01tun0`。
- Windows 访问：`http://wsl.x01:<port>`，不要用 `127.0.0.1`。
- 冷启动：dockerd 清理 3–4 分钟；Postgres 强停后恢复约 4 分钟。

## 来源

由 `D:\WSL2\索引\`（系统档案）与 `D:\WSL2\应用\`（运维卡片）整理而来。本地原件保留在 `D:\WSL2`，本仓库用于版本化与分支隔离。
