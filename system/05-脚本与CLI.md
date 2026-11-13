# 05 · 脚本与 CLI

## 1. `x01` CLI

位置：`~/infra/bin/x01`（5588 B），对 compose 项目的薄封装。

| 命令 | 作用 | 示例 |
|---|---|---|
| `x01 ls` | 列出所有模块与状态 | `x01 ls` |
| `x01 ps` | 容器状态总览 | `x01 ps` |
| `x01 up <module>` | `compose up -d` | `x01 up dev/forgejo` |
| `x01 down <module>` | `compose down` | `x01 down sec/mobsf` |
| `x01 restart <module>` | 重启模块 | `x01 restart data/postgres` |
| `x01 logs <module> [-f]` | 看日志 | `x01 logs dev/forgejo -f` |
| `x01 path <module>` | 打印模块目录 | `x01 path net/mihomo` |
| `x01 net` | 网络体检：接口、出口 IP、策略组、节点池、上次刷新 | `x01 net` |

模块名就是相对路径：`data/postgres`、`data/mongo`、`dev/forgejo`、`sec/mobsf`、`sec/mitmproxy`、`ops/portainer`。

## 2. mihomo 工具

| 文件 | 大小 | 作用 |
|---|---|---|
| `~/infra/net/mihomo/bin/mihomo` | 62 MB | 主程序 1.19.33 with_gvisor |
| `~/infra/net/mihomo/bin/refresh-providers` | 2690 B | 拉 5 个订阅 → sanitize → 落盘 → `PUT /configs` 热加载；失败不覆盖 |
| `~/infra/net/mihomo/bin/sanitize-provider` | 1388 B | 修 latin1/utf8 双重编码、BOM、控制字符 |
| `~/infra/net/emergency/probe.sh` | — | 三通道出口探测（本机 mihomo / Windows 网关 / 反向给 Windows） |

```bash
# 手动刷订阅（timer 已停用）
cd ~/infra/net/mihomo && sudo -u mihomo ./bin/refresh-providers

# 三通道探测
~/infra/net/emergency/probe.sh

# API 快查
curl -s 127.0.0.1:9090/version
curl -s 127.0.0.1:9090/proxies | jq '."🚀 节点选择".now'
```

## 3. `~/scripts/bootstrap/`（20 个）

按用途分组：

### 安装 / 环境

| 脚本 | 作用 |
|---|---|
| `wsl-setup-node.sh` | 安装 Node（本地前缀） |
| `wsl-background-installs.sh` | 后台批量安装 |
| `wsl-install-mcp.sh` | 安装 MCP 依赖 |
| `wsl-install-semgrep.sh` | 安装 Semgrep |
| `wsl-install-openchamber.sh` | 安装 OpenChamber |

### OpenChamber 生命周期

| 脚本 | 作用 |
|---|---|
| `wsl-start-openchamber.sh` | 启动 |
| `wsl-restart-openchamber.sh` | 重启 |
| `wsl-status.sh` | 状态 |

### 配置同步

| 脚本 | 作用 |
|---|---|
| `wsl-copy-opencode-config.sh` | 复制 opencode 配置 |
| `sync-opencode-config.mjs` | 同步配置（Node） |
| `wsl-write-config.sh` | 写配置 |

### 插件 / MCP

| 脚本 | 作用 |
|---|---|
| `wsl-plugin-add.sh` | 添加插件 |
| `wsl-disable-plugins.mjs` | 禁用插件 |
| `wsl-enable-plugins.sh` | 启用插件 |
| `wsl-debug-plugins.sh` | 插件调试 |
| `wsl-check-mcp.sh` | MCP 连通性检查 |

### 校验 / 调试

| 脚本 | 作用 |
|---|---|
| `wsl-verify.sh` | 基础校验 |
| `wsl-verify2.sh` | 扩展校验 |
| `wsl-debug2.sh` | 调试 |
| `wsl-help.sh` | 帮助 |

## 4. Forgejo 镜像推送

| 项 | 值 |
|---|---|
| 仓库 | `http://127.0.0.1:3005/xiaoming/wsl-infra`（私有，约 30 文件） |
| 本地副本 | `~/repo/wsl-infra`（620 KB） |
| 推送脚本 | `~/scripts/push-wsl-infra.sh` |
| 令牌 | `~/.config/x01/forgejo.token`（600，勿外传） |

脚本流程：读令牌 → 临时写入 git 凭据 → 推送 `~/infra` → 推送后删除临时凭据。仓库里的 `.env` 全部是 `CHANGE_ME`，不要提交真实值。

```bash
~/scripts/push-wsl-infra.sh
```

## 5. 已清理的一次性脚本

`D:\WSL2\_deploy\` 下的 `openapi-paths.sh`、`insta-source.sh`、`insta-extra.sh` 已于 2026-11-12 删除。

它们只是用 `jq` 过滤 InstaCloud OpenAPI JSON 的临时查询，依赖：

```text
C:\Users\24999\AppData\Local\Temp\opencode\insta-openapi.json
```

该临时文件不随项目保存，脚本本身也已无重复使用价值；需要时按 OpenAPI 原文重写即可。

## 6. Windows 侧脚本

| 脚本 | 位置 | 作用 |
|---|---|---|
| `wslip.ps1` / `wslip.cmd` | `D:\Network\小工具\port\` | 同步 `wsl.<别名>` hosts，需 UAC |
| 计划任务 `wsl-hosts-sync` | Windows 任务计划 | 登录后 15 秒自动跑 |
| `start_docker_wsl.bat` | goofish 项目 | Windows 侧拉起 Docker/WSL |
| `start_sniper*.bat` | goofish 项目 | 启动监控 |
| `start_chrome_debug.ps1` | goofish `scripts/` | 开 Chrome 9223 调试端口 |
| `start_windows_proxy.ps1` | goofish `scripts/` | Windows 代理 |

## 7. 配置目录

### `~/.config/openchamber/`

```text
bin/ chats/ logs/ run/ managed-opencode/
git-credential-endpoint.json   install-id-web
jwt-secret                     opencode-trust.json
preferences.json               relay-identity.json
sessions-unread.json           settings.json
skills-github-meta.json        ui-passkeys.json
ui-password.txt
```

### `~/.config/opencode/`

```text
opencode.json      7383 B
agents/ commands/  skills/（81 项）
service.json
```

### `~/.config/x01/`

```text
forgejo.token      推送令牌，600
```

## 8. 常用巡检一行命令

```bash
# 系统
uptime -p; free -h; df -h / /mnt/d

# 网络
curl -s -o /dev/null -w '%{http_code}\n' 127.0.0.1:9090/version
getent hosts wsl.x01

# Docker
docker ps -a --format 'table {{.Names}}\t{{.Status}}'
docker system df

# goofish
curl -s -o /dev/null -w '%{http_code}\n' 127.0.0.1:8086/health

# x01 模块
~/infra/bin/x01 ps
```
