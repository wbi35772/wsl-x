# Android 运行环境选型与部署研究

> 日期：2026-10-21
> 范围：本机（Windows 11 / Ryzen 5 5600 / RTX 2070 SUPER / 32GB）上的 Android 运行方案、虚拟化选型、指纹检测对抗、云手机部署
> 标注说明：✅ = 本机实测或 API 核实；📐 = 量级估算，未实测；⚠️ = 结论有条件

---

## 0. TL;DR

| 目标 | 方案 | 结论 |
|---|---|---|
| 本地跑 Linux 后端/工具链 | **WSL2 `Ubuntu-24.04`** | ✅ 已装，待重启生效 |
| 要图形/游戏/手感 | **MuMu 12（宿主 GPU 直通）** | 与 Hyper-V 互斥 |
| 要自动化吞吐/多开密度 | **Hyper-V + redroid** | 无 GPU，软件渲染 |
| 要「像真机」过风控 | **ARM 云机 或 真机** | x86 是根因，改参数救不回 |
| 只跑某个特定 App 做自动化 | **AOSP Emulator (WHPX) + scrcpy** | 最省事，单实例够用 |

**三条硬结论**
1. WSL2 跑安卓需要重编内核（binder），Hyper-V 里跑不需要 —— 但都拿不到 GPU。
2. `ro.product.cpu.abilist` 可以伪造；`ro.dalvik.vm.native.bridge`、`/proc/cpuinfo`、`GL_RENDERER`、传感器、key attestation 伪造不了。
3. 风控抓的是**矛盾**，不是单项。改一项就制造一片新矛盾。

---

## 1. 宿主基线

| 项 | 值 |
|---|---|
| OS | Windows 11 专业工作站版 10.0.26300.9711 |
| CPU | AMD Ryzen 5 5600（6C/12T） |
| RAM | 31.9 GB |
| GPU | NVIDIA GeForce RTX 2070 SUPER（8GB），驱动 32.0.16.1088 |
| 显示 | 2560×1440 |
| 虚拟化 | 固件已开（HypervisorPresent=True） |
| 代理 | HTTP `127.0.0.1:10808`，mixed `127.0.0.1:7897` |
| 已装虚拟化软件 | 无（VMware / VirtualBox / 模拟器均未安装） |
| 已启用组件 | `VirtualMachinePlatform` ✅、`Microsoft-Windows-Subsystem-Linux` ✅、`Microsoft-Hyper-V-All` ✅（均 `RebootPending`） |

---

## 2. 虚拟化层次对比

三者不在同一层：**WSL2 是跑在 Hyper-V 架构上的轻量 VM**，不是并列的第三种技术。

| | WSL2 | Hyper-V | VMware Workstation |
|---|---|---|---|
| 类型 | Utility VM（共享 Windows hypervisor） | Type-1 | Type-2 |
| 能跑什么 | 只有 Linux（固定内核 6.18.54.1） | 任意 guest | 任意 guest，老系统兼容最好 |
| 启动 | ~1s | 20–60s | 20–60s |
| 隔离 | 弱（`/mnt/c` 直通、进程互操作） | 硬边界 | 硬边界 |
| 磁盘 IO | ext4 in VHDX 接近原生；`/mnt/c` 很慢 | 接近原生 | 接近原生 |
| 网络 | NAT / **mirrored**（WSL 服务直接出现在宿主 localhost） | 虚拟交换机 | 桥接/NAT/host-only，最直观 |
| 快照 | ❌ 只能 export/import | ✅ Checkpoint | ✅ 快照树/克隆 |
| GPU | WSLg + `/dev/dxg`（paravirt） | GPU-P 仅 Windows guest | SVGA3D，桌面应用最顺 |
| USB 直通 | ❌（需 usbipd 转发） | 有限 | ✅ 最好 |
| 成本 | 免费 | Pro/Enterprise 自带 | 17.x 起个人免费 |

**共存关系**：启用 WSL2 后 Windows hypervisor 常驻，VMware 17.5+ 可走 WHP API 继续跑（性能略降），老版本直接不兼容。VirtualBox 7 能跑但更慢。

---

## 3. Android 方案总览

| 方案 | 实现 | ABI | GPU | 启动 | 单实例内存 | 密度（32GB/6C） |
|---|---|---|---|---|---|---|
| MuMu 12 | 闭源 VM（VirtualBox 系改造） | x86_64 + houdini 转译 | ✅ 宿主直通 | 20–40s | 3–4GB | 3–4 |
| AOSP Emulator | qemu + WHPX | x86_64（+ 转译） | ✅ host（gfxstream） | 15–30s | 2–3GB | 3–4 |
| Hyper-V + redroid | 容器（共享宿主内核） | x86_64 | ❌ 软件渲染 | **3–5s** | 1.5–2GB | **6–8** |
| ARM 云机 | ARM 服务器 + redroid | **arm64-v8a** | ❌ 软件渲染 | 3–5s | 1.5–2GB | 6–8/节点 |
| Windows + Waydroid | 需 WSLg + 自编内核 | x86_64 | ❌ | 5–10s | 2GB | 4–5 |
| 真机农场 | 物理手机 + USB 群控 | **arm64-v8a** | ✅ | — | — | 按机柜 |

📐 上表启动时间/内存为量级估算，非实测。

---

## 4. 方案 A：MuMu 12（商业模拟器）

**优势**
- 宿主 GPU 直通，60–120fps，游戏/重图形唯一可行路线
- 图形化多开管理器，批量克隆/同步操作
- 机型预设、root 开关成熟

**劣势**
- 与 Hyper-V **互斥**：启用后需「兼容模式」或直接起不来，帧率掉 20–40%
- 闭源、有遥测/推广
- 特征库被各平台收录最全
- 转译层 `libhoudini` 是硬指纹

**结论**：这台机器若留给 MuMu，就不要在同一台机上做 redroid 农场。

---

## 5. 方案 B：AOSP Emulator（Windows 宿主 / WHPX）

```powershell
# 因为已启用 VirtualMachinePlatform，AEHD/HAXM 不可用，只能走 WHPX
emulator -accel-check          # 期望 WHPX(10) is installed and usable
emulator -avd a1 -accel on -gpu host -cores 4 -memory 4096 `
         -skin 720x1280 -no-boot-anim -no-snapshot-save -writable-system
```

- 开源（AOSP + qemu），可脚本化 `avdmanager` 批量建实例
- `-gpu host` 走宿主 GPU（gfxstream），图形介于 MuMu 和 redroid 之间
- 特征：`goldfish` 内核、`ranchu` 硬件、`ro.kernel.qemu=1`
- 适合「单实例 + scrcpy 操作 + 自动化脚本」，不适合大规模多开

---

## 6. 方案 C：Hyper-V + redroid（推荐给自动化/多开）

### 6.1 为什么优于 WSL

redroid **不是模拟器**，它不虚拟化，把 Android 用户态直接跑在宿主 Linux 内核的容器里，靠内核 `binder` 通信。

| | WSL2 | Hyper-V + Ubuntu VM |
|---|---|---|
| binder | 微软内核不带，**必须自编内核** | Canonical 官方内核带，`modprobe` 即可 |
| 内存上限 | 受 `.wslconfig` 硬限制 | 自主分配 |
| 独立网络出口 | 差（只有一套 mirrored） | ✅ 每容器 netns |
| 快照 | export/import | ✅ Checkpoint + 差分盘 |
| 稳定性 | WSL 升级可能丢失 `/dev/binder` | ✅ |

**关键反直觉点：redroid 不需要嵌套虚拟化**（不碰 KVM）。只有要在 VM 里再跑 QEMU/VirtualBox 时才需要。

### 6.2 部署

**Windows 侧**

```powershell
Get-NetAdapter | Format-Table Name,InterfaceDescription,Status   # 先确认网卡名

New-VMSwitch -Name "External" -NetAdapterName "以太网" -AllowManagementOS $true

New-VM -Name redroid-host -Generation 2 -MemoryStartupBytes 10GB `
  -NewVHDPath D:\VMs\redroid\redroid.vhdx -NewVHDSizeBytes 120GB `
  -SwitchName "External"
Set-VMProcessor redroid-host -Count 6
Set-VMMemory redroid-host -DynamicMemoryEnabled $false
Set-VMFirmware redroid-host -EnableSecureBoot Off     # 自编模块时必需
Add-VMDvdDrive redroid-host -Path D:\WSL2\pkg\iso\ubuntu-24.04.4-live-server-amd64.iso
Set-VMFirmware redroid-host -FirstBootDevice (Get-VMDvdDrive redroid-host)
Start-VM redroid-host
```

**VM 内**

```bash
sudo apt update
sudo apt install -y docker.io linux-modules-extra-$(uname -r) adb

sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"
ls -l /dev/binder /dev/hwbinder /dev/vndbinder    # 三个都在才算过

docker run -itd --privileged --name r1 -p 5555:5555 \
  --cpus=2 --memory=2g -v /lib/modules:/lib/modules:ro \
  redroid/redroid:13.0.0_64only-latest \
  androidboot.redroid_width=720 androidboot.redroid_height=1280 \
  androidboot.redroid_dpi=280 androidboot.redroid_gpu_mode=guest \
  androidboot.use_memfd=true

adb connect 127.0.0.1:5555
adb -s 127.0.0.1:5555 shell getprop ro.build.version.release   # 13
```

**多开 + 快照**

```bash
for i in $(seq 1 4); do
  docker run -itd --privileged --name r$i -p $((5555+i)):5555 \
    --cpus=2 --memory=2g -v /lib/modules:/lib/modules:ro \
    redroid/redroid:13.0.0_64only-latest \
    androidboot.redroid_width=720 androidboot.redroid_height=1280 \
    androidboot.redroid_dpi=280 androidboot.redroid_gpu_mode=guest
done
```

```powershell
Checkpoint-VM -Name redroid-host -SnapshotName clean
Restore-VMSnapshot -VMName redroid-host -Name clean -Confirm:$false
```

### 6.3 镜像 tag（Docker Hub API 核实，2026-10-21 ✅）

`redroid/redroid` 全部 tag 是**多架构 manifest（amd64,arm64）**，没有单独的 `_arm64` tag，aarch64 机器 pull 时自动取 arm64。

活跃 tag：`16.0.0_64only-latest`（2025-06）、`15.0.0_64only-latest`、`13.0.0_64only-latest`（最常用稳定档）、`10.0.0-latest`。

---

## 7. 方案 D：ARM 云手机

**核心价值不是「云」，是「ARM」**：`ro.product.cpu.abilist = arm64-v8a` 是真的，`native.bridge` 为空，`/proc/cpuinfo` 是 ARM。

```bash
uname -m                                   # 必须 aarch64
sudo apt update
sudo apt install -y docker.io linux-modules-extra-$(uname -r) adb
sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"
ls -l /dev/binder*

docker run -itd --privileged --name r1 -p 5555:5555 \
  --cpus=2 --memory=2g -v /lib/modules:/lib/modules:ro \
  redroid/redroid:13.0.0_64only-latest \
  androidboot.redroid_width=720 androidboot.redroid_height=1280 \
  androidboot.redroid_dpi=280 androidboot.redroid_gpu_mode=guest \
  androidboot.use_memfd=true

adb connect 127.0.0.1:5555
adb -s 127.0.0.1:5555 shell getprop ro.product.cpu.abi   # 期望 arm64-v8a
```

**改指纹的正确方式**：redroid 只透传 `androidboot.*` → `ro.boot.*`。`ro.product.model/brand/fingerprint` **不能**用启动参数改，必须：

```bash
# 改镜像内 build.prop（永久）
docker exec -u root r1 sh -c "sed -i 's/^ro.product.model=.*/ro.product.model=SM-G998B/' /system/build.prop"
# 或 Magisk/Zygisk 模块 resetprop（重启仍生效）
```

**云机 ≠ 免死金牌**：机房 IP 段（阿里云/腾讯云/华为云）被风控公开标记。必须给每实例挂住宅/移动出口：

```bash
apt install -y redsocks iptables
cat >/etc/redsocks.conf <<'EOF'
base { log_debug = off; log_info = off; daemon = on; redirector = iptables; }
redsocks {
  local_ip = 127.0.0.1; local_port = 12345;
  ip = RESIDENTIAL_SOCKS_HOST; port = 1080;
  type = socks5; login = "USER"; password = "PASS";
}
EOF
systemctl restart redsocks
# 再给每个容器 veth 做 tproxy 规则指向 12345
```

---

## 8. 方案 E：真机农场

| 项 | 说明 |
|---|---|
| 硬件 | 二手机（红米/Pixel）¥300–700/台 + 多口 USB Hub + 独立供电 |
| 控制 | `adb devices` + STF / scrcpy 多路 |
| 优势 | 指纹天然真实，Play Integrity 可过 |
| 劣势 | 体积、供电、散热、人工维护、无法弹性扩容 |

---

## 9. 指纹与检测矩阵（核心章节）

### 9.1 各检测点的真实取值

| 检测点 | 读取方式 | MuMu | x86 redroid | AOSP Emu | ARM redroid | 真机 | 可改性 |
|---|---|---|---|---|---|---|---|
| `ro.product.cpu.abilist` | prop | 可含 arm64 ✅ | `x86_64,x86` ❌ | x86 ❌ | `arm64-v8a` ✅ | arm64 ✅ | **可改** |
| `ro.dalvik.vm.native.bridge` | prop | `libhoudini.so` ❌ | 空 ✅ | 空 ✅ | 空 ✅ | 空 ✅ | 改空则失去 ARM 兼容 |
| `/proc/cpuinfo` `vendor_id`/`model name` | 文件 | `AuthenticAMD` ❌ | 同 ❌ | 同 ❌ | ARM ✅ | ARM ✅ | 需 bind-mount，`/sys` 仍漏 |
| `GL_RENDERER` | GL 查询 | `RTX 2070 SUPER` ❌ | SwiftShader ❌ | 宿主 GPU ⚠️ | 软件 ❌ | Adreno/Mali ✅ | 需 hook |
| 传感器清单 | `SensorManager`/HAL | 部分模拟 ⚠️ | 无 ❌ | 部分 ⚠️ | 无 ❌ | 全 ✅ | HAL 层难伪造 |
| `ro.build.tags` / `ro.debuggable` | prop | `test-keys` 常见 ❌ | 可改 ✅ | 可改 ✅ | 可改 ✅ | `release-keys` ✅ | **可改** |
| `ro.kernel.qemu` / `goldfish` / `ranchu` | prop/文件 | 无 | 无 | 有 ❌ | 无 | 无 | 可改 |
| `/system/lib64/libhoudini.so` | 文件 | 存在 ❌ | 无 ✅ | 无 ✅ | 无 ✅ | 无 ✅ | 删了就没 ARM 兼容 |
| Play Integrity BASIC | API | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ✅ | 需 props 修复 |
| Play Integrity DEVICE | 指纹白名单 | ❌ 多数 | ❌ | ❌ | ⚠️ 需真机指纹 | ✅ | 需有效 fingerprint |
| Play Integrity STRONG | 硬件 key attestation | ❌ | ❌ | ❌ | ⚠️ 需 keybox | ✅ | 只能靠泄漏 keybox，会被拉黑 |

### 9.2 MuMu 的「ARM 死结」

| | 声明成 arm64 机型 | 能跑 ARM-only 应用 |
|---|---|---|
| 保留 `native.bridge=libhoudini.so` | ✅ abilist 可写 arm64-v8a | ✅ 转译执行 |
| 清空 `native.bridge` | ✅ 更自洽 | ❌ houdini 不加载，ARM-only so 直接 `UnsatisfiedLinkError` |

检测方只看一条 `getprop ro.dalvik.vm.native.bridge`，非空即转译层。**两头不能都要。**

### 9.3 「多 ABI APK + 清空 bridge」到底是什么意思

APK 里的 native 库按 ABI 分目录：

```
lib/arm64-v8a/libfoo.so
lib/armeabi-v7a/libfoo.so
lib/x86_64/libfoo.so        ← 有这一份，就不需要转译
```

- 若 APK 内含 `lib/x86_64/`，应用可在 x86 上**原生执行**，不需要 houdini
- 此时清空 `native.bridge` 不会崩，少一个硬指纹
- 若只有 arm 库（现在多数国内 App 如此），清空 bridge = 应用起不来

**但这不是「能过检测」**，只解决 6 个检测点里的 1 个，而且引入新矛盾：声明的 abilist 是 arm64，但 `/proc/self/maps` 里加载的是 `/system/lib64/libfoo.so` 的 x86_64 路径 —— 会交叉比对的应用照样能看出来。

查 APK 的 ABI：

```bash
unzip -l app.apk | grep 'lib/'
# 或
aapt dump badging app.apk | grep native-code
# 或
apkanalyzer apk features app.apk | grep abi
```

典型情况：

| APK 情况 | 策略 |
|---|---|
| 有 `lib/x86_64/` | 可清空 bridge，自洽度提升 |
| 只有 `armeabi-v7a`/`arm64-v8a` | 必须保留 houdini，露 `native.bridge` |
| 混合（x86_64 + arm + 风控 SDK 只有 arm） | 按「最脏」的库决定，通常还是得留 |

### 9.4 一致性 checklist（真正被抓的地方）

| 矛盾点 | 露馅示例 |
|---|---|
| 机型 ↔ GPU | 声明 Galaxy S21，`GL_RENDERER` 是 RTX 2070 |
| 机型 ↔ 传感器数 | 旗舰机声明 12 个，实际 0 |
| 机型 ↔ 分辨率/DPI | S21 是 1080×2400，跑 720×1280 |
| fingerprint ↔ 补丁级别 | 版本对得上但 `security_patch` 为空 |
| 时区 ↔ 出口 IP | UA 说美东，IP 在德国 |
| 语言 ↔ MCC/MNC | `en-US` 但运营商是中国 |
| `ro.build.tags` | 仍是 `test-keys` / `ro.debuggable=1` |
| 已装应用 | Xposed/Magisk/自动化工具裸露（需 HMA 隐藏） |
| 电池/温度 | 恒 100%、恒 25℃ |
| 内存映射 ↔ ABI 声明 | 声明 arm64，maps 里是 x86_64 路径 |

**结论：改单项 = 制造新矛盾。**

### 9.5 风控权重排序（经验判断 ⚠️）

| 权重 | 维度 |
|---|---|
| ★★★★★ | 出口 IP 质量（住宅/移动 vs 机房，同 IP 多号） |
| ★★★★☆ | 指纹内部一致性 |
| ★★★★☆ | 支付方式 / 手机号归属与 IP 国家一致 |
| ★★★☆☆ | 行为节奏 |
| ★★☆☆☆ | TLS / JA3-JA4 指纹 |
| ★★☆☆☆ | 是否运行在虚拟环境 |
| ★☆☆☆☆ | 具体是 Hyper-V 还是 VMware |

### 9.6 客户端改包路线（APK 补丁）

思路：不伪造环境，直接**拆掉/骗掉 App 里的检测逻辑**。对「只看客户端」的检测最直接有效。

| 维度 | 改环境 | 动态 Hook | 改包固化 |
|---|---|---|---|
| 覆盖 | 一次配置管所有 App | 单 App，进程内生效 | 单 App，安装即生效 |
| 维护 | 环境特征变了才动 | 每次运行都要挂 | 每次 App 更新都要重做 |
| 壳 / VMP | 无关 | 可绕过（不碰 DEX） | **最大成本**，先脱壳 |
| 签名校验 | 不受影响 | 不影响 | 必须绕过 |
| Play Integrity | 可能挂 BASIC | 可能挂 | **必然挂**（签名摘要变了） |
| 服务端信号（IP/行为/支付） | 无效 | 无效 | 无效 |

**能拆掉的检测类别**

- 模拟器 / root / Frida / Xposed / 多开检测
- 设备指纹采集（返回值替换）
- 传感器数量、`GL_RENDERER`、GPU 型号校验
- 调试器 / ptrace / 端口检测（27042）
- 虚拟空间（VirtualApp 环境）检测

**标准流程**

```bash
# 1. 静态定位
jadx -d out app.apk
grep -rn "isEmulator\|FINGERPRINT\|/proc/cpuinfo\|native.bridge\|getSensorList\|27042" out/sources | head

# 2. 动态验证（改完立即确认是否还触发）
frida -U -f com.target.app -l hook.js

# 3. 固化
apktool d app.apk -o work
# 改 work/smali*/... 下的判定逻辑
apktool b work -o patched-unsigned.apk
apksigner sign --ks key.jks --out patched.apk patched-unsigned.apk
```

**Frida 骨架（Java 层）**

```js
Java.perform(function () {
  var Sys = Java.use('java.lang.System');
  Sys.getProperty.overload('java.lang.String').implementation = function (k) {
    if (k === 'ro.dalvik.vm.native.bridge') return '';
    if (k === 'ro.kernel.qemu') return '0';
    return this.getProperty(k);
  };
  var Build = Java.use('android.os.Build');
  Build.MODEL.value = 'SM-G998B';
  Build.MANUFACTURER.value = 'samsung';
});
```

**native 层必须单独拦**（Java hook 拦不到 libc 调用）：

```js
Interceptor.attach(Module.findExportByName('libc.so', '__system_property_get'), {
  onEnter: function (a) { this.k = a[0].readCString(); },
  onLeave: function (r) {
    if (this.k === 'ro.dalvik.vm.native.bridge') r.writeUtf8String('');
  }
});
```

**五道硬门槛**

| 门槛 | 现象 | 绕过方式 |
|---|---|---|
| 加固壳（乐固/梆梆/易盾/爱加密） | jadx 出来是壳 | frida-dexdump / youpk / BlackDex 脱壳后再改 |
| VMP（DEX 虚拟化） | 关键函数是 opcode 数组 | 只能动态 hook，静态改不动 |
| 签名校验 | 改包后闪退或接口 403 | hook `PackageManager.getPackageInfo` 的 `signatures`，或改 so 里的哈希常量 |
| DEX 完整性自校验 | 校验和/CRC 不符 | hook `MessageDigest`、`CRC32` 或改写死值 |
| Play Integrity | BASIC 就挂 | 改包**无解**（签名摘要变了），只能靠原签名 + 服务端放水 |

**结论**：改包适合「自用自动化 + 目标 App 无强完整性校验」；对挂了 Play Integrity 或强服务端校验的目标，改包是**比改环境更强的负面信号**（签名变了、校验和不符，直接一票否决）。

### 9.7 实战：MuMu 跑 Facebook 注册的环境探测

#### 9.7.1 入口选择

| 入口 | 检测面 | 难度 |
|---|---|---|
| Facebook App（`com.facebook.katana`） | 设备指纹 + 传感器 + 完整性 + 行为 | 最高 |
| Facebook Lite | 略少，字段同源 | 高 |
| `m.facebook.com`（移动 Web） | 浏览器指纹 + TLS | 中 |
| Windows 指纹浏览器 | 浏览器指纹 + TLS | **中，FB 主战场** |
| Instagram 注册再关联 | 独立风控，相对松 | 中高 |

FB 对 **Android 客户端**的设备校验严于 Web；MuMu 恰好在「严的那一侧 + 最易识破的实现」。**若目标只是拿到 FB 号，MuMu 不是最优路径。**

#### 9.7.2 最快的探测法：读 UA

FB App 每个请求的 UA 把设备画像全写在里面：

```
[FBAN/FB4A;FBAV/495.0.0.32.100;FBBV/...;FBDM/{density=2.0,width=720,height=1280};
FBLC/en_US;FBRV/...;FBCR/T-Mobile;FBMF/Xiaomi;FBBD/Redmi;FBPN/com.facebook.katana;
FBDV/M2007J3SY;FBSV/11;FBOP/1;FBCA/arm64-v8a:]
```

| 字段 | 含义 | 对应系统真值 |
|---|---|---|
| `FBDV` | device model | `ro.product.model` |
| `FBMF` | manufacturer | `ro.product.manufacturer` |
| `FBBD` | brand | `ro.product.brand` |
| `FBSV` | Android 版本 | `ro.build.version.release` |
| `FBCA` | CPU ABI | `ro.product.cpu.abilist` |
| `FBDM` | 屏幕密度/宽/高 | `wm size` / `wm density` |
| `FBLC` | 语言地区 | `persist.sys.locale` |
| `FBCR` | 运营商 | SIM / MCC-MNC |

逐项对齐系统真值，就是破绽清单：

```bash
adb shell getprop ro.product.model
adb shell getprop ro.product.manufacturer
adb shell getprop ro.product.brand
adb shell getprop ro.build.version.release
adb shell getprop ro.product.cpu.abilist
adb shell wm size; adb shell wm density
adb shell getprop persist.sys.locale
adb shell getprop gsm.operator.alpha
```

#### 9.7.3 抓包链路（要过 pinning）

```bash
# 1. MuMu 开 root，推 frida-server（x86_64 版）
adb root
adb push frida-server-16.7.x-android-x86_64 /data/local/tmp/fs
adb shell "chmod 755 /data/local/tmp/fs && /data/local/tmp/fs &"
frida-ps -U

# 2. 宿主
mitmproxy --listen-port 8080

# 3. MuMu 内代理指向宿主（VirtualBox 系 NAT，网关通常 10.0.2.2）
adb shell ip route | grep default
adb shell settings put global http_proxy 10.0.2.2:8080

# 4. 证书装成系统证书（Android 7+ 不信任用户证书）
openssl x509 -inform PEM -subject_hash_old -in ~/.mitmproxy/mitmproxy-ca-cert.pem | head -1
cp ~/.mitmproxy/mitmproxy-ca-cert.pem <hash>.0
adb root && adb remount
adb push <hash>.0 /system/etc/security/cacerts/
adb shell chmod 644 /system/etc/security/cacerts/<hash>.0
adb reboot
```

脱 pinning（`unpin.js`）：

```js
Java.perform(function () {
  try {
    var TM = Java.use('javax.net.ssl.X509TrustManager');
    var SC = Java.use('javax.net.ssl.SSLContext');
    var TrustAll = Java.registerClass({
      name: 'com.x.TA', implements: [TM],
      methods: {
        checkClientTrusted: function () {},
        checkServerTrusted: function () {},
        getAcceptedIssuers: function () { return []; }
      }
    });
    var tm = [TrustAll.$new()];
    var init = SC.init.overload('[Ljavax.net.ssl.KeyManager;',
      '[Ljavax.net.ssl.TrustManager;', 'java.security.SecureRandom');
    init.implementation = function (km, t, sr) { init.call(this, km, tm, sr); };
  } catch (e) { console.log('tm fail ' + e); }

  try {
    var P = Java.use('okhttp3.CertificatePinner');
    P.check.overload('java.lang.String', 'java.util.List').implementation = function () {};
    P.check.overload('java.lang.String', '[Ljava.security.cert.Certificate;').implementation = function () {};
  } catch (e) { console.log('pinner fail ' + e); }
});
```

```bash
frida -U -f com.facebook.katana -l unpin.js
```

mitmproxy 里按 `graph.facebook.com` / `b-graph.facebook.com` 过滤，`fb_api_req_friendly_name` 含 `regist` / `signup` / `account` 的是注册链路。

#### 9.7.4 APK 选择

```bash
unzip -l fb.apk | grep 'lib/'     # 看有没有 lib/x86_64/
apkid fb.apk                      # 看 packer / anti_vm 特征
```

FB 现版只发 `armeabi-v7a` + `arm64-v8a`（Google 64 位要求后砍了 x86），**没有 `lib/x86_64/` → MuMu 必须走 houdini → `native.bridge` 这一关过不去**。§9.3 的「多 ABI + 清空 bridge」对 FB 无效。

| 选项 | 建议 |
|---|---|
| 最新全量 FB | 不推荐（检测最全） |
| **Facebook Lite** | 可试（字段同源，检测略少） |
| 老版本 FB（v300 以下） | 不推荐（强制升级） |
| `m.facebook.com` | 可作对照路 |

**实用做法**：Lite 与 Web 两路同时试，哪条能过用哪条；不要在两套环境上同时烧手机号。

#### 9.7.5 环境配置（反直觉：选烂机型）

| 项 | 推荐值 | 理由 |
|---|---|---|
| 机型 | Redmi Note 8 / Galaxy A51 这类中低端 | 传感器少（4–6）、GPU 是中端、真机保有量大 |
| 别选 | S23/S24、iPhone | 传感器 12+，你有几个就露几个 |
| Android 版本 | **11 或 12** | 老版本兼容好、检测项少 |
| 分辨率/DPI | 严格对齐机型（如 1080×2340 / 400dpi） | 不对齐 = 第一条矛盾 |
| 时区 | 与出口 IP 国家一致 | 美国 IP → `America/New_York` |
| 语言 | `en-US` | 别留中文残留 |
| **GMS** | **不装** | 装了才有 Play Integrity；FB 直装 APK 照样跑，少一道校验 |
| root | 关（frida 调试时临时开） | 常开 = `su` 路径可见 |
| 开发者选项 | 关 | `adb_enabled=1` 是特征 |
| 传感器 | 补不了 → 选少传感器的机型自圆其说 | — |
| 电池 | MuMu 固定 100%，无解 | 别让它成为唯一异常项 |

#### 9.7.6 真机基线 diff（最有效）

```
真机抓包  → 提取 UA + 上报字段
MuMu 抓包 → 提取 UA + 上报字段
diff 两份 → 每一处差异就是独有破绽
```

比任何检测工具都准：比的是「FB 实际收到的报文」，不是「理论检测项」。

#### 9.7.7 权重与注册节奏

| 层 | 权重 |
|---|---|
| IP 质量（住宅/移动，独享） | ★★★★★ |
| 手机号 / 邮箱质量 | ★★★★☆ |
| 设备指纹一致性（MuMu 能改的就这层） | ★★★☆☆ |
| 行为节奏 | ★★★☆☆ |
| App 入口选择 | ★★☆☆☆ |
| TLS / HTTP2 指纹 | ★★☆☆☆ |

| 环节 | 要点 |
|---|---|
| IP | 住宅/移动、独享、国家与手机号一致；机房段直接判死 |
| 手机号 | 实体卡 > 接码平台（号段被标记，注册即封） |
| 邮箱 | 不用一次性域名 |
| 设备预热 | 注册前 1–2 天正常使用（常用 App、Wi-Fi 记录、相册） |
| 隔离 | 一机一 IP 一号，绝不共用 |
| 注册后 | 24h 内不加好友、不发帖、不改资料 |
| 失败处理 | 同 IP 连续失败 2 次就换 IP，硬试本身是信号 |

---

## 10. 开源工具清单（GitHub API 核实，2026-10-21 ✅）

| 用途 | 仓库 | ★ | 最后提交 | 状态 | 说明 |
|---|---|---|---|---|---|
| Play Integrity 修复 | `osm0sis/PlayIntegrityFork` | 4609 | 2026-10-16 | 活跃 | 改 props 过 `<A13` verdict |
| 密钥证明伪造 | `5ec1cff/TrickyStore` | 6421 | 2025-11-30 | 活跃 | 需自备 keybox.xml |
| Hook 框架 | `LSPosed/LSPosed` | 25119 | 2026-10-14 | 活跃 | Zygisk 底座 |
| Frida 工具箱 | `Ch0pin/medusa` | 2359 | 2026-10-16 | 活跃 | 改 device id / 隐藏 root / 绕 pinning |
| 运行时探针 | `sensepost/objection` | 9453 | 2026-09-17 | 活跃 | `android root disable` 等 |
| 应用虚拟化 | `asLody/VirtualApp` | 11111 | 2026-10-21 | 活跃 | Java 层全面可控 |
| 容器化安卓 | `budtmo/docker-android` | 15993 | 2026-10-21 | 活跃 | noVNC + **MCP server**，可接 AI agent |
| 串流 | `Genymobile/scrcpy` | 152710 | 2026-10-20 | 活跃 | 事实标准 |
| 浏览器控制台 | `NetrisTV/ws-scrcpy` | 2582 | 2026-10-20 | 活跃 | 网页看/点多台 |
| 设备农场 | `DeviceFarmer/stf` | 4613 | 2026-10-02 | 活跃 | 支持 adb connect 设备 |
| 自测检测项 | `strazzere/anti-emulator` | 840 | 2021-01-22 | 停滞 | 经典样本，用来体检 |
| 属性伪造（历史） | `MagiskHidePropsConfig` | — | — | **404** | 已下架，需找 fork |
| Play Integrity 初代 | `chiteroman/PlayIntegrityFix` | — | — | **404** | 已下架 |
| 隐私管理 | `M66B/XPrivacyLua` | 556 | 2022-11-25 | **归档** | 停更 |

**存活率提示**：这类项目平均 1–2 年被下架/删库。**先 fork 存档再改**，不要把流程绑死在单一仓库。

---

## 11. 成本模型（📐 量级估算）

| 方案 | 单实例折算 | 8 实例/月 | 备注 |
|---|---|---|---|
| Oracle Ampere A1 免费额度（4C/24G） | ¥0 | ¥0 | 抢手、可能回收 |
| Hetzner CAX21（8C/16G ARM） | ~¥8 | ~¥70 | 性价比高 |
| 阿里云倚天 4C16G | — | ~¥200 | 国内低延迟 |
| 商业云手机（红手指类） | ¥20–60/台 | ¥160–480 | 免运维、IP 需另配 |
| 真机农场 | ¥300–700/台（一次性） | 电费 | 指纹最真 |

---

## 12. 踩坑清单

| 坑 | 现象 | 解法 |
|---|---|---|
| `HCS_E_SERVICE_NOT_AVAILABLE` | WSL2/VM 起不来 | `vmcompute`/`hns` 未创建 → 必须重启完成组件安装 |
| 只开 VirtualMachinePlatform 没有 vmcompute | `sc start vmcompute` 报 1060 | 同上，重启后才出现 |
| WSL 内核无 binder | `modprobe binder_linux` 找不到模块 | 自编内核（`CONFIG_ANDROID_BINDER_IPC`/`BINDERFS`/`ASHMEM`/`PSI`） |
| 代理只监听 127.0.0.1 | VM/容器内连不上 10808 | 开「允许局域网连接」+ 防火墙放行，或 VM 内自建 socks5 |
| Hyper-V Default Switch | 重启后 NAT 网段变化 | 用 External 桥接交换机 |
| Secure Boot | 自编内核模块加载失败 | VM 固件关 Secure Boot，或 MOK 签名 |
| `androidboot.*` 改不了 `ro.product.*` | 改启动参数无效 | 只能改镜像 build.prop 或 Magisk resetprop |
| x86 模拟器装 ARM-only APK | `UnsatisfiedLinkError` | 保留 houdini / 换多 ABI APK / 换 ARM 环境 |
| 同一台机同时要 MuMu 和 Hyper-V | MuMu 起不来或掉帧 | 物理隔离或分机 |

---

## 13. 当前状态与下一步

### 已完成 ✅
| 项 | 状态 |
|---|---|
| 系统组件（VMP / WSL / Hyper-V All） | 已启用，待重启 |
| WSL 引擎 3.0.3.0（离线 MSI，内核 6.18.54.1） | 已安装 |
| `C:\Users\24999\.wslconfig`（12GB/8vCPU/mirrored） | 已配置 |
| Ubuntu rootfs（24.04.5） | 已校验，待导入 |
| `D:\WSL2\pkg\setup.sh` | 就绪（用户 dev / 美东时区 / 工具链） |
| 登录自启任务 `X01-WSL-Setup` | 已注册 |
| Ubuntu Server ISO 24.04.4 | ✅ 已下载并校验（SHA256 `e907d92e…8433`，与官方一致，3.17GB） |

### 待办
1. **重启**（唯一卡点）：`Restart-Computer -Force`
2. 验证 WSL：`wsl --version` / `wsl -l -v` / `id dev` / `timedatectl`
3. ~~决策：这台机器做 **MuMu/AOSP 图形调试机** 还是 **redroid 农场**（二选一）~~ → **已决策：WSL + MuMu**，Hyper-V 角色已关闭、`redroid-host` VM 不建
4. 装 MuMu，实测是否支持 WHPX（决定要不要 `bcdedit /set hypervisorlaunchtype off`）
5. 若走养号：先确定出口 IP 方案（住宅代理），再谈指纹

### 已排除 ❌

| 环境 | 判定 | 依据 |
|---|---|---|
| Muse 的 VM（Cloud Hypervisor 微 VM，x86_64） | **不可部署云机** | `/proc/modules` 不存在 → **`CONFIG_MODULES=n`，内核无模块子系统**（`apt install linux-modules-extra` 也救不回）；`/dev/kvm` 不存在、SVM 未透传；capabilities effective 为空；无公网 IPv4。完整实测见 `MUSE-VM.md` |
| Hyper-V + redroid（本机） | **暂不采用** | 决策改为 WSL + MuMu；且 WSL2 的 hypervisor 常驻会与 MuMu 争抢硬件虚拟化 |

---

## 附录 A：已执行的关键命令

```powershell
# 1. 启用组件
dism /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism /online /enable-feature /featurename:Microsoft-Hyper-V-All /all /norestart

# 2. 离线安装 WSL（不走 Store）
msiexec /i D:\WSL2\pkg\wsl-3.0.3-x64.msi /qn /norestart /l*v wsl-msi.log

# 3. 导入发行版（重启后）
& 'C:\Program Files\WSL\wsl.exe' --import Ubuntu-24.04 D:\WSL2\Ubuntu-24.04 `
  D:\WSL2\pkg\ubuntu-base-24.04.5-amd64.tar.gz --version 2
```

## 附录 B：验证命令

```powershell
wsl --version
wsl --list --verbose
wsl -d Ubuntu-24.04 -u root -- bash -lc "cat /etc/os-release|head -2; id dev; date"
Get-Content D:\WSL2\setup-task.log -Tail 30
```

```bash
# Android 环境自检
getprop ro.product.cpu.abilist
getprop ro.dalvik.vm.native.bridge
getprop ro.build.tags
head -30 /proc/cpuinfo | grep -E 'vendor_id|model name'
cat /proc/self/maps | grep -m3 '\.so'
```

## 附录 C：候选主机五闸门

任何「这台机器能不能跑 Android 容器 / 云机」的问题，跑这一遍就有答案（与 `MUSE-VM.md` §7 同一份脚本）：

```bash
#!/usr/bin/env bash
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

| 结果 | 判定 |
|---|---|
| `module-subsystem = NO` | 立即放弃，任何 apt 都救不回 |
| `arch = x86_64` | 只能转译，`native.bridge` 必然非空 |
| `/dev/kvm = no` + `cap_sys_admin = no` | 虚机路线全灭 |
| `public_ipv4 = none` | 做号环境一票否决（共享出口） |

四条里中两条，不用往下折腾。

---

## 相关文档

| 文档 | 内容 |
|---|---|
| `README.md` | 索引、当前状态、已定决策 |
| `BASELINE.md` | 本机 WSL / 虚拟化环境基准线 |
| `MUSE-VM.md` | 沙箱 VM 实测规格（那份完整自检回显的来源） |
