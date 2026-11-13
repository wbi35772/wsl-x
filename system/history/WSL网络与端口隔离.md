# WSL 网络与端口隔离说明

日期：2026-11-01
环境：Windows 11 build 26300.9711（ProfessionalWorkstation）、WSL 3.0.3.0、Ubuntu-24.04（WSL2）
关联：`doc/WSL部署分析.md`（WARP 与网关部署的早期分析）

本文记录 2026-11-01 对「WSL 抢占 Windows 端口」的排查、隔离方案、多发行版命名，以及 WSL / 虚拟机 TUN 与宿主 TUN 的叠加关系。所有结论以本机实测为准。

---

## 0. 结论速查

| 问题 | 结论 |
|---|---|
| 为什么 WSL 端口会出现在 Windows | WSL2 默认 NAT + `localhostForwarding=true`，`wslrelay.exe` 把 WSL 内所有监听镜像到 Windows 的 `127.0.0.1` / `::1` |
| 怎么彻底隔离 | `.wslconfig` 设 `localhostForwarding=false`，`wslrelay` 不再启动，Windows 侧零 WSL 监听 |
| 关掉后怎么访问 | 走 WSL 的 IP；hosts 写 `wsl.<别名>`，当前为 `172.30.196.173  wsl.x01` |
| 多个发行版是不是各自一个 IP | **不是**。所有发行版共用一个 VM、一个 IP、一套端口；`wsl.x01` / `wsl.x02` 只是别名 |
| WSL 里再开 TUN 会影响宿主吗 | 不会改宿主的转发表；但它会和 WSL 内已有的 TUN 抢路由 |
| 虚拟机里开 TUN 呢 | NAT 模式的流量仍经宿主路由，会被宿主 TUN 二次接管；桥接模式直出物理网卡，互不影响 |
| 同一台 Windows 开两个 TUN | 不行，同一个路由表里两个默认路由会互相抢 |

---

## 1. 现象与根因

### 现象

开机后（Windows 尚未启动任何代理），WSL 里的服务先占住了大量端口：

- `10808` 被 `::1` 占用，`v2rayN` 的 xray 只能绑 `127.0.0.1:10808`
- Windows 侧 `10800-10899`、`3005`、`5432` 等端口上出现大量监听
- 监听进程是 `wslrelay.exe`，不是 WSL 里的程序本身

### 根因

WSL2 默认 NAT 网络，`.wslconfig` 里 `localhostForwarding=true`（默认值）。WSL 内任何 `0.0.0.0` / `127.0.0.1` / `[::]` 监听都会被 `wslrelay.exe` 镜像到 Windows 的 loopback。

关键点：**`wslrelay` 只做转发，真正的监听在 WSL 里。** 在 Windows 上杀进程、改端口都不会解决，必须从 WSL 侧或 `localhostForwarding` 开关处理。

当时代码环境里，`clash-proxy-demo` 容器里的 mihomo 开了 10000 段共 100 个 mixed 端口，实测：

```text
WSL 内 mihomo 监听   1798 条
Windows 侧镜像       3586 条（IPv4 + IPv6 各一份）
```

---

## 2. 处置一：把 demo 的端口段整体搬走

为了不和 Windows 常用端口（10808、8081 等）冲突，demo 的配置做了整体平移：

| 项目 | 值 |
|---|---|
| 端口范围 | `10001-11793` → `30000-31792`（整体 +19999） |
| 配置备份 | `config.yaml.bak-20261101_014030` |
| 容器名 | `clash-proxy-demo`（旧容器保留为 `clash-proxy-demo.bak`） |
| 重启策略 | `--restart no`（开机不再自启） |
| Dashboard | `8085` |
| 控制器 | `127.0.0.1:9093` |
| Mixed 入口 | `7900` |
| 网络 | `network_mode: host` |

重建时漏过 `DASHBOARD_PORT`，dashboard 回落到 `8081` 撞上 mitmproxy，容器 `exit 1`；补上后正常。停止后 Windows 侧镜像监听归零。

恢复运行：

```bash
docker start clash-proxy-demo
```

注意 `restart=no`，重启 WSL 后它不会自己回来；需要常驻就改 `--restart unless-stopped`，但端口区间已经是 30000+，不会再抢 10808。

---

## 3. 处置二：关闭端口镜像（根本隔离）

编辑 `C:\Users\<你>\.wslconfig`：

```ini
[wsl2]
memory=12GB
processors=8
swap=4GB
swapFile=D:\\WSL2\\Ubuntu-24.04\\swap.vhdx
vmIdleTimeout=86400000
networkingMode=nat
dnsTunneling=false
autoProxy=false
firewall=false
localhostForwarding=false
```

备份：`C:\Users\24999\.wslconfig.bak-20261101_015318`

生效：

```powershell
wsl --shutdown
```

`wsl --shutdown` 会停掉所有发行版和容器，`unless-stopped` 的容器在下次启动后自动恢复。

实测结果：

| 检查 | 结果 |
|---|---|
| `wslrelay` 进程 | 不再出现 |
| `127.0.0.1:3005` | 不通 |
| `172.30.196.173:3005` | 通，HTTP 200 |
| Windows 侧 `3005` / `8787` 监听 | 0 条 |

从此 Windows 与 WSL 的端口空间彻底分开：Windows 用 `127.0.0.1`，WSL 用 WSL IP。

---

## 4. 访问方案：hosts 命名 `wsl.<别名>`

WSL 的 IP 在 `wsl --shutdown` 后会变，直接记 IP 不可靠，因此用 hosts 自动同步。

### 命名规则

```text
wsl.<别名>  →  <发行版的当前 IP>
```

别名与发行版的映射放在 `D:\Network\小工具\port\distros.txt`：

```text
# 别名=WSL 发行版名；每个条目生成一条 wsl.<别名>
x01=Ubuntu-24.04
```

当前 hosts 内容：

```text
172.30.196.173  wsl.x01
```

### 自动同步

| 项目 | 值 |
|---|---|
| 脚本 | `D:\Network\小工具\port\wslip.ps1` |
| 入口 | `D:\Network\小工具\port\wslip.cmd`（需要 UAC） |
| 计划任务 | `wsl-hosts-sync`，登录后 15 秒，最高权限，Interactive |
| 日志 | `D:\Network\小工具\port\wslip.log` |
| hosts 备份 | 每次改前生成 `hosts.bak-<时间>` |

脚本会：

1. 读取 `distros.txt`，逐个执行 `wsl -d <发行版> hostname -I` 取第一个非回环 IPv4
2. 删除 hosts 里所有 `wsl` / `wsl.*` / 旧名 `wslvm.local` 的行
3. 写入 `wsl.<别名>` 并 `ipconfig /flushdns`

手动同步（IP 变了、或刚加发行版）：

```powershell
D:\Network\小工具\port\wslip.cmd
```

### 新增一个系统

```powershell
wsl --import x02 D:\WSL2\x02 <rootfs.tar> --version 2
```

然后在 `distros.txt` 加一行：

```text
x02=x02
```

跑一次 `wslip.cmd`，`wsl.x02` 即出现；登录时任务也会自动补。

---

## 5. 多发行版的真实关系：同 IP、同端口

WSL2 不是「一个发行版一个虚拟机」，而是**一个轻量 VM 里装多个发行版**，它们共用 VM 的网卡和网络命名空间。

2026-11-01 用 `alpine-minirootfs-3.24.3` 临时导入 `x02` 实测（测完已 `wsl --unregister` 并删除目录）：

| 测试 | 结果 |
|---|---|
| x01 `eth0` | `172.30.196.173/20` |
| x02 `eth0` | `172.30.196.173/20`（完全相同） |
| x02 访问 `localhost:3005` | 拿到 x01 里 Forgejo 的页面 |
| x02 监听 `3005` | `nc: bind: Address in use` |

结论：

- 所有发行版共享同一个 IP、同一套端口空间
- 发行版之间隔离的只有文件系统、进程、用户，网络不隔离
- `wsl.x01` / `wsl.x02` 是同一个地址的两个名字，名字不产生隔离

### 端口规划建议

- 多个系统必须**全局唯一端口**，否则后启动的绑定失败
- 按系统划分端口段：x01 用 `30000-30999`，x02 用 `31000-31999`
- 只是要跑不同发行版的服务，优先放一个发行版里用 Docker，端口只在一处管理
- 真要网络隔离，用独立虚拟机（见第 6 节）

### 关于发行版重命名

当前 WSL 3.0.3.0 不支持 `wsl --manage <distro> --rename`（报 `WSL_E_INVALIDARG`）。`x01` 是网络别名，发行版在 `wsl -l` 里仍显示 `Ubuntu-24.04`。

真要改名只能导出再导入，`ext4.vhdx` 已 24.7 GB，需要约 25 GB 空闲和十几分钟停机，收益仅为显示名，暂不做。

---

## 6. TUN 叠加：WSL、虚拟机与宿主

### 本机当前实况

| 位置 | 内容 |
|---|---|
| Windows | `xray_tun`（Wintun，Up），默认路由之一 |
| Windows 默认路由 | `192.168.1.1`（以太网，metric 0）、`0.0.0.0`（xray_tun，metric 0） |
| WSL | `x01tun0`，`198.18.0.1/30`，mihomo 提供 |
| WSL 策略路由 | `ip rule` 中 `not from all iif lo lookup 2022`，table 2022 默认走 `198.18.0.2 dev x01tun0` |

实测出口 IP：

```text
Windows（经 xray_tun）  104.28.162.99
WSL 内 curl             149.22.87.240
```

两者不同，说明 **WSL 的出站先被自己的 `x01tun0` 接管**，并没有直接落到宿主 `xray_tun`。WSL 里的 mihomo 进程自身（uid 994）通过 `8999: from all uidrange 994-994 lookup main` 绕过 TUN，避免回环。

> 补充修正：早前把 WSL 里 WARP 握手失败完全归因于运营商封锁并不完整。`x01tun0` 的 fake-IP 与策略路由会先截走这些报文（`tx=888 rx=0` 与此吻合）；旧记录显示宿主侧 WARP 可用（8/8），说明运营商并非主因。详见 `doc/WSL部署分析.md`。

### 各种组合的行为

| 部署方式 | 它的 TUN 影响宿主？ | 宿主 TUN 影响它？ | 说明 |
|---|---|---|---|
| WSL + 自带 TUN | 否 | 否（先被自己的 TUN 截走） | 当前状态；两层 TUN 在 WSL 内争路由 |
| WSL + 无 TUN | 否 | **是** | NAT 出站落到宿主路由，被 `xray_tun` 捕获 |
| Windows VM + NAT | 否 | **是** | VMware NAT / Hyper-V Default Switch 由宿主转出 |
| Windows VM + 桥接 | 否 | **否** | 二层直出物理网卡，绕开宿主 IP 栈 |
| 同一 Windows 再开 TUN | **是**（抢默认路由） | 是 | 同一路由表只能有一个默认出口 |

### 建议

1. **最干净**：项目放 Windows VM，网络用桥接。VM 的 TUN 管 VM，宿主 `xray_tun` 管 Windows，零耦合。
2. **放 WSL**：可以，但 WSL 内已有 `x01tun0`，项目再开 TUN 会与它抢默认路由。要么停掉 mihomo 的 TUN，要么让项目复用现有 TUN/代理，不要并存两套。
3. **WSL 无自带 TUN 时**，宿主 TUN 会接管 WSL 出站；如果不想被接管，在 Windows 侧按 WSL 网段（`172.30.192.0/20`）加直连规则。
4. **不要**在宿主 Windows 上再开第二个 TUN 跑项目，会和 `xray_tun` 抢默认路由。

---

## 7. 工具与文件清单

| 路径 | 用途 |
|---|---|
| `D:\Network\小工具\port\wslport.exe` / `wslport.cmd` | 查询某个端口在 WSL 内是哪个进程占用（10808 → xray，3005 → forgejo，27017 → mongo） |
| `D:\Network\小工具\port\wslpp.exe` / `wslpp.cmd` | 按白名单把 WSL 端口转发到 Windows localhost |
| `D:\Network\小工具\port\wslip.ps1` / `wslip.cmd` | 同步 `wsl.<别名>` 到 hosts |
| `D:\Network\小工具\port\distros.txt` | 别名与发行版映射 |
| `D:\Network\小工具\port\wslip.log` | hosts 同步日志 |
| `D:\Network\小工具\port\README.md` | 上述工具的安装与使用说明 |
| `C:\Users\24999\.wslconfig` | WSL 全局配置（`localhostForwarding=false`） |
| `C:\ProgramData\wslpp` | wslpp 安装目录（任务当前 Disabled） |

`wslpp` 说明：曾把 7 个 `0.0.0.0` 端口转回 Windows localhost（222/3005/8000/8080/8081/8787/9443），实测 3005 可用。它只扫描 `0.0.0.0`/`[::]`，所以只绑 WSL `127.0.0.1` 的服务（5432、27017、7891、9099）转不出来。改为 `wsl.<别名>` 方案后任务已 Disabled；重新启用会破坏「Windows 零 WSL 监听」的隔离，不建议混用。

---

## 8. 常用诊断命令

Windows：

```powershell
wsl.exe -l -v
wsl.exe -d Ubuntu-24.04 -e hostname -I
Get-Content "$env:USERPROFILE\.wslconfig"
Get-Process wslrelay -ErrorAction SilentlyContinue
Get-NetAdapter | Where-Object InterfaceDescription -match 'wintun'
Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Sort-Object RouteMetric
netstat -ano | Select-String ':3005\s'
Test-NetConnection 172.30.196.173 -Port 3005
```

WSL 内：

```bash
ip -brief addr
ip rule
ip route show table 2022
ss -lntp
ps aux | grep -Ei 'mihomo|clash|sing-box' | grep -v grep
curl -s --max-time 8 https://api.ipify.org
```

端口归属：

```powershell
D:\Network\小工具\port\wslport.cmd 10808
```

---

## 9. 回退

### 恢复端口镜像

`.wslconfig` 改回 `localhostForwarding=true`，然后 `wsl --shutdown`。`wslrelay` 会重新出现，10808 等端口的冲突也会回来。

### 移除 hosts 方案

1. 删除 hosts 里所有 `wsl` / `wsl.*` 行
2. `Unregister-ScheduledTask wsl-hosts-sync`
3. 之后只能用 IP 访问 WSL

### 恢复 demo 容器端口

`config.yaml.bak-20261101_014030` 是搬家前的配置；恢复时同步改回容器环境变量 `PORT_START=10001`、`DASHBOARD_PORT=8081`，并注意 8081 与 mitmproxy 冲突。

### 启用 wslpp

```powershell
wslpp.exe install
```

任务 `wslpp` Enable 后，白名单端口会重新出现在 Windows localhost；与 `wsl.<别名>` 方案二选一。

---

## 10. 变更记录

| 时间 | 变更 |
|---|---|
| 2026-11-01 01:40 | demo 端口段 10001-11793 → 30000-31792，容器重建为 `--restart no` |
| 2026-11-01 01:53 | `localhostForwarding=false`，`wsl --shutdown`，`wslrelay` 消失 |
| 2026-11-01 01:56 | 安装 wslpp（后停用） |
| 2026-11-01 01:20 | hosts 方案落地，先 `wsl` 后改 `wsl.x01` |
| 2026-11-01 | 临时导入 Alpine x02 验证多发行版同 IP，测完删除 |

---

## 11. 待办 / 未验证

- `wsl.x01` 的 IP 在 NAT 模式重启后会变，目前靠登录任务与手动 `wslip.cmd` 更新，没有事件触发
- 发行版重命名需要导出/导入 24.7 GB，未执行
- 桥接虚拟机方案未实际搭建，结论基于网络原理与 NAT/桥接差异
- WSL 内 `x01tun0` 与项目自带 TUN 的共存未做长期压测，目前只验证了静态路由关系
