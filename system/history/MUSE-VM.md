# Muse 沙箱 VM — 实测规格与能力边界

> 实测日期：2026-10-21
> 主机名：`htch-runtime`
> 用途定位：**通用代码执行沙箱**（不是 Android 宿主，不是固定出口）
> 结论：**不可用于 Android 容器 / 云手机 / 长期在线服务**，其余用途按 §5 判断

---

## 1. 身份判定

```
systemd-detect-virt  →  systemd-nspawn
DMI product_name     →  cloud-hypervisor
DMI sys_vendor       →  Cloud Hypervisor
/proc/1/cgroup       →  0::/..
```

两个读数不矛盾，拼起来是：

```
[宿主 KVM] → [Cloud Hypervisor 微VM] → [systemd-nspawn 容器]  ← 你在这里
                  ↑ DMI 穿透上来            ↑ detect-virt 报这个
```

**要点：这是一个「微 VM 里的容器」，不是一台可长期占用的服务器。** 宿主机名 `htch-runtime` 也印证其定位是运行时（runtime），通常按会话创建、按需回收。

## 2. 硬件与资源

| 项 | 值 |
|---|---|
| 架构 | `x86_64`（`amd64`） |
| CPU | AMD EPYC 9D25（126 核宿主），**分到 2 vCPU / 2 核**，1 线程/核 |
| 内存 | 7.7 GiB 总量，**采样时 available 仅 206 MiB** |
| 根文件系统 | overlay，7.5 G |
| 块设备 | `vda` 7.4G、`vdb` 7.5G、`vdc` 1G、`vdd` **100G（持久卷）** |
| OS | Ubuntu 24.04.5 LTS |

**内存是硬约束**：206 MiB 可用意味着连 `git clone` 大仓库、`docker pull`、编译都会触发 OOM。这是超卖环境的典型读数。

## 3. 内核与模块（决定性）

| 项 | 值 | 含义 |
|---|---|---|
| 内核 | `7.0.0-39-generic` | 非 Ubuntu 24.04 主线（6.8/6.11/6.14），平台自建，沿用 `-generic` 命名 |
| `/proc/modules` | **不存在** | `CONFIG_MODULES=n` — **内核没有模块子系统** |
| `/lib/modules/7.0.0-39-generic` | 不存在 | 无模块文件 |
| `modprobe binder_linux` | `FATAL: Module not found` | 加载不了 |
| `/dev/binder` `/dev/hwbinder` `/dev/vndbinder` | 全部不存在 | Android 容器无基础 |

> **重要**：`apt install linux-modules-extra-$(uname -r)` **无效**。模块包只是放 `.ko` 文件，内核没有模块加载器，装了也加载不了。这条路已彻底关闭。

## 4. 虚拟化与权限

| 项 | 值 | 后果 |
|---|---|---|
| `lscpu` Hypervisor vendor | KVM（CPUID 签名，Cloud Hypervisor 默认沿用） | 正常 |
| `/dev/kvm` | 不存在 | 不能跑 QEMU/KVM 加速 |
| `vmx` / `svm` 标志 | 无 | 未透传 |
| nested 参数文件 | 不存在 | 无嵌套虚拟化 |
| 能力集 | Bounding = 全集；**Current(effective) = 空** | 只能降不能升 |
| `CAP_SETFCAP` | 无 | 不能给二进制打 file capabilities 提权 |
| docker | 未安装 | — |
| `cgroup memory.max` / `cpu.max` | 读不到 | 资源上限不透明 |

**能力集的实际含义**：`unshare -n`、`mount --bind`、`iptables -t nat` 全部需要 `CAP_SYS_ADMIN`，而 effective 集为空 → 一个都做不了。redroid 需要的 `--privileged` 容器、netns 出口分流、代理隔离，全部没有基础。

## 5. 网络

| 项 | 值 |
|---|---|
| `lo` | `127.0.0.1/8` |
| `host0` | `198.19.0.2/30`，网关 `198.19.0.1` |
| 出口 | 仅 IPv6 `2606:54c1:1:eff::19d:2bb` |
| 公网 IPv4 | **无** |
| 入站端口 | 不可用（NAT 后） |

`198.19.0.0/16` 落在 **RFC 2544 基准测试保留段**（`198.18.0.0/15`）内，说明前面至少还有一层 NAT。

**对账号类用途是致命的**：出口是共享 NAT IPv6，没有独立公网 IPv4，同 IP 多号是风控第一条命中的信号。

## 6. 能力矩阵

| 用途 | 可行 | 说明 |
|---|---|---|
| 跑 Python / Node / 编译 / CI 类任务 | ✅ | 内存小，重负载需注意 |
| 临时抓包 / 协议调试 | ✅ | 出站可用 |
| 当 adb 控制器连远端设备 | ⚠️ | 出站可用，但入口不可控、可能随时回收 |
| Android 容器（redroid / Waydroid） | ❌ | 无模块子系统 + 无 caps + 无 binder |
| QEMU 全系统模拟 | ❌ | 无 `/dev/kvm`，TCG 在 2 vCPU/206MiB 下不可用 |
| 固定出口 / 账号环境 | ❌ | 无独立公网 IPv4，共享 NAT |
| 长期在线服务 | ❌ | 运行时容器定位，非持久实例 |

## 7. 复测命令

```bash
#!/usr/bin/env bash
# 任意候选主机跑一遍：五闸门筛 Android 容器可行性
p(){ printf '%-20s %s\n' "$1" "$2"; }
p "arch" "$(uname -m)"
[ -e /proc/modules ] && p "module-subsystem" "yes" \
  || p "module-subsystem" "NO → CONFIG_MODULES=n，永久死刑"
[ -e /dev/kvm ] && p "/dev/kvm" "yes" || p "/dev/kvm" "no"
capsh --print 2>/dev/null | grep -q 'Current:.*cap_sys_admin' \
  && p "cap_sys_admin" "yes" || p "cap_sys_admin" "no"
[ -e /dev/binder ] && p "binder" "yes" || p "binder" "no"
p "public_ipv4" "$(curl -4 -s --max-time 5 https://ifconfig.me || echo none)"
p "mem_avail" "$(free -m | awk '/Mem:/{print $7"Mi"}')"
```

判读表：

| 结果 | 判定 |
|---|---|
| `module-subsystem = NO` | 立即放弃，任何 apt 都救不回 |
| `arch = x86_64` | 只能转译，`native.bridge` 必然非空 |
| `/dev/kvm = no` + `cap_sys_admin = no` | 虚机路线全灭 |
| `public_ipv4 = none` | 做号环境一票否决（共享出口） |

## 8. 备注

- 该机器后续由使用者另作他用（通用执行环境 / 工具链），**不再纳入 Android 方案评估**。
- 原计划的两条路（Hyper-V + redroid、Muse VM + redroid）均已归档，见 `ANDROID-ENV.md` §13「已排除」。
