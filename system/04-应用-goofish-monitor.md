# 04 · 应用：goofish-hardware-sniper

## 1. 它是什么

闲鱼（Goofish）硬件好价监控，基于 `ai-goofish-monitor` 思路的自建版本：

- Playwright 驱动浏览器抓闲鱼搜索结果；
- AI 对商品标题/图片做相关性判断；
- Web UI 可视化管理任务、查看结果；
- 多任务并行 + cron 调度 + 随机抖动；
- 按价格、包邮、发布时间、地区筛选；
- 通知走 ntfy / 企业微信 / Bark / Telegram / Webhook；
- 账号状态与代理轮换；
- Docker 单容器部署。

| 项 | 值 |
|---|---|
| 项目目录 | `/mnt/d/goofish-hardware-sniper`（838 MB） |
| 容器 | `goofish-hardware-sniper` |
| 镜像 | `goofish-hardware-sniper:local`（1.64 GB） |
| Web UI | `http://wsl.x01:8086/` |
| 登录 | `admin` / `***`（`WEB_USERNAME` / `WEB_PASSWORD`） |
| 健康检查 | `GET /health` → 200 |
| 重启策略 | unless-stopped |
| 时区 | `Asia/Shanghai` |

## 2. 容器参数

compose：`/mnt/d/goofish-hardware-sniper/docker-compose.yaml`（dev 版；另有 `.base` / `.release` Dockerfile）

| 挂载（host → 容器） | 用途 |
|---|---|
| `.env` → `/app/.env` | 环境变量 |
| `accounts/` | 闲鱼账号状态 |
| `config.json` → `/app/config.json` | 旧版任务配置（遗留） |
| `data/` → `/app/data` | SQLite 主库 |
| `images/` | 商品图片缓存 |
| `jsonl/` | 结构化结果导出 |
| `logs/` | 运行日志 |
| `price_history/` | 价格历史 |
| `prompts/` | AI 提示词 |
| `scripts/` | 运维脚本 |
| `state/` → 账号/浏览器状态 | `state.json`、`xianyu_state.json` |

关键环境变量（密钥已脱敏）：

| 变量 | 值 / 含义 |
|---|---|
| `SERVER_PORT` | `8000`（容器内；宿主映射 8086） |
| `APP_DATABASE_FILE` | `/app/data/app.sqlite3` |
| `OPENAI_BASE_URL` | `https://prod-warp-multi-warp-iad-052055-00tcy0ga6yt.compute.instacloud-edge.com/v1` |
| `OPENAI_BASE_URL_FALLBACK` | `https://prod-warp-multi-warp-fra-2948e9-305b27qm91j.compute.instacloud-edge.com/v1` |
| `OPENAI_MODEL_NAME` | `deepseek-v4.1-flash-free` |
| `OPENAI_API_KEY` | `***` |
| `WEB_USERNAME` / `WEB_PASSWORD` | `admin` / `***` |
| `RUN_HEADLESS` | `true` |
| `LOGIN_IS_EDGE` | `false` |
| `PCURL_TO_MOBILE` | `true`（PC 链接转移动端） |
| `ACCOUNT_STATE_DIR` | `state` |
| `STATE_FILE` | `xianyu_state.json` |
| `ENABLE_THINKING` | `false` |
| `ENABLE_RESPONSE_FORMAT` | `true` |
| `AI_ANALYSIS_CONCURRENCY` | `1` |
| `PRE_LLM_FILTER_ENABLED` | `true`（先规则过滤再送 AI，省钱） |
| `SCHEDULER_JITTER_MIN_SECONDS` / `MAX` | `0` / `180` |
| `DETAIL_FETCH_LIMIT_PER_RUN` | `6` |
| `BROWSER_CDP_URL` | `http://host.docker.internal:9223` |
| `HOST_GATEWAY_IP` | `172.30.192.1` |
| `TZ` | `Asia/Shanghai` |

> `HOST_GATEWAY_IP` 是 WSL 的 NAT 网关。WSL IP 变了它通常不变，但若 Windows 侧代理端口改了，也要同步 `.env`。

## 3. 任务（SQLite 为准，11 个 / 启用 7 个）

| # | 任务 | 状态 | 价格区间（元） | cron | 关键词 |
|---|---|---|---|---|---|
| 1 | 14600KF_无显卡半套机 | 停用 | 1400–2500 | `*/12 * * * *` | 14600KF 无显卡 |
| 2 | 9700X_无显卡半套机 | 停用 | 1800–3000 | `*/15 * * * *` | 9700X B650 |
| 3 | 5060Ti_个人整机 | 停用 | 4800–6300 | `*/10 * * * *` | 5060Ti 主机 |
| 4 | RTX5060Ti_单卡狙击 | 停用 | 3150–3850 | `*/8 * * * *` | RTX 5060Ti |
| 5 | 14600KF_Z790板U套装 | **启用** | 1200–1900 | `2-59/10 * * * *` | 14600KF Z790 |
| 6 | RTX5060Ti_8G单卡 | **启用** | 3300–3950 | `4-59/8 * * * *` | RTX 5060Ti 8G |
| 7 | DDR4_32G套条 | **启用** | 600–1000 | `6-59/13 * * * *` | DDR4 32G 套条 |
| 8 | DDR5_16G单条 | **启用** | 900–1600 | `1-59/23 * * * *` | DDR5 16G 内存 |
| 9 | 致态三星_1T固态 | **启用** | 500–900 | `3-59/15 * * * *` | 1T 固态 |
| 10 | 2K_IPS显示器 | **启用** | 400–800 | `5-59/17 * * * *` | 2K IPS 显示器 |
| 11 | 14600KF_5060Ti整机 | **启用** | 6800–8500 | `7-59/19 * * * *` | 14600KF 5060Ti |

调度技巧：启用任务的分钟偏移分别是 `2/4/6/1/3/5/7`，避免同一分钟同时开 7 个浏览器任务把内存打满。

### 旧配置 `config.json`

文件里还有 4 个旧任务（T1–T4，均 `*/3`，价格 3200–3850 / 850–1550 / 850–1500 / 4800–6200）。**以 Web UI / SQLite 的 11 个任务为准**；`config.json` 只作历史种子，改它不会同步到新任务表。

## 4. 数据

`data/app.sqlite3`（5.6 MB）：

| 表 | 行数 | 内容 |
|---|---|---|
| `tasks` | 11 | 任务定义 |
| `result_items` | 171 | 命中的商品 |
| `price_snapshots` | 1708 | 价格快照 |
| `app_metadata` | 4 | 应用元数据 |
| `result_blacklist_rules` | 0 | 黑名单规则 |

目录占用：

| 目录 | 大小 |
|---|---|
| `data/` | 5.6 MB 主库 |
| `logs/` | 1.5 MB |
| `state/` | 36 KB（`state.json` 252 KB、`xianyu_state.json` 8.7 KB） |
| `accounts/` | 12 KB |
| `images/` `jsonl/` `price_history/` | 空 |

## 5. 运行行为

| 机制 | 说明 |
|---|---|
| 调度抖动 | 每个任务触发后随机等 0–180 秒再开抓，降低同时登录/抓取特征 |
| 失败保护 | `FailureGuard`：连续 3 次失败暂停任务 86400 秒（24 小时） |
| AI 并发 | 1（`AI_ANALYSIS_CONCURRENCY`），避免免费模型限流 |
| 每次详情抓取 | 最多 6 个（`DETAIL_FETCH_LIMIT_PER_RUN`） |
| 预过滤 | 先关键词/价格/包邮规则过滤，再送 AI |
| 通知 | ntfy / 企业微信 / Bark / Telegram / Webhook，按任务配置 |

采集时日志显示 `DDR4_32G套条`、`14600KF_Z790板U套装`、`DDR5_16G单条` 曾因连续失败被暂停重试；24 小时后自动恢复，或手动在 UI 里重新启用。

## 6. 代码结构

```text
/mnt/d/goofish-hardware-sniper/
├─ src/
│  ├─ app.py / config.py / scraper.py / ai_handler.py
│  ├─ ai_message_builder.py / parsers.py / prompt_utils.py
│  ├─ rotation.py / failure_guard.py / keyword_rule_engine.py
│  ├─ api/ core/ domain/ infrastructure/
│  └─ services/            20+ 个：scheduler、ai_service、pre_llm_filter、
│                          price_history、notification、task_*、result_* 等
├─ web-ui/                 前端
├─ scripts/                任务/调试/登录脚本
├─ tests/
├─ chrome-extension/       浏览器扩展
├─ chrome-cdp-profile/     CDP 用户目录
├─ Dockerfile / Dockerfile.base / Dockerfile.release
├─ docker-compose.yaml
├─ config.json / .env
└─ data/ state/ logs/ accounts/ ...
```

## 7. 脚本

| 脚本 | 用途 |
|---|---|
| `scripts/apply_hardware_tasks.py` | 批量写入硬件任务 |
| `scripts/apply_14600kf_5060ti_build_tasks.py` | 写入 14600KF + 5060Ti 整机任务 |
| `scripts/set_task_crons.py` | 批量改 cron |
| `scripts/extract_login_state.py` | 从浏览器提取登录态 |
| `scripts/solve_slider.py` | 滑块验证处理 |
| `scripts/cdp_proxy.py` | CDP 代理 |
| `scripts/start_chrome_debug.ps1` | Windows 侧开 Chrome 调试端口 9223 |
| `scripts/start_windows_proxy.ps1` | Windows 侧代理 |
| `scripts/windows_wsl_proxy.py` | Windows ↔ WSL 代理转发 |
| `scripts/_probe_ai_endpoints.py` | 探测 AI 端点可用性 |
| `scripts/_probe_filters.py` | 探测筛选参数 |
| `scripts/_query_recent.py` / `_query_scores.py` | 查最近结果 / 分数 |
| `scripts/_status_check.py` | 状态检查 |
| `scripts/_remote_ai_check.py` | 远程 AI 检查 |
| `scripts/run_live_smoke.sh` | 真机冒烟测试 |

## 8. 常用操作

```bash
# 看状态
docker ps --filter name=goofish-hardware-sniper
curl -s http://127.0.0.1:8086/health

# 看日志（最近 200 行）
docker logs --tail 200 -f goofish-hardware-sniper

# 重启
docker restart goofish-hardware-sniper

# 进容器
docker exec -it goofish-hardware-sniper bash

# 备份数据库（热备，WAL 安全）
python3 - <<'PY'
import sqlite3
src = sqlite3.connect('/mnt/d/goofish-hardware-sniper/data/app.sqlite3')
dst = sqlite3.connect('/mnt/d/goofish-hardware-sniper/data/app.backup.sqlite3')
src.backup(dst)
dst.close(); src.close()
print('backup ok')
PY
```

## 9. 注意

1. **UI 端口是 8086，容器内是 8000。** 文档/脚本里两个数字都出现，别混。
2. **AI 端点走 InstaCloud warp 域名。** 域名失效或 warp 池不可用时，AI 分析会失败；`OPENAI_BASE_URL_FALLBACK` 是 fra 备用。
3. **首次/掉登录需要 Windows Chrome CDP。** 先跑 `start_chrome_debug.ps1`（9223），容器通过 `host.docker.internal:9223` 接管。
4. **改任务优先用 Web UI。** 直接改 `config.json` 不会影响 SQLite 里的 11 个任务。
5. **免费模型有速率限制。** 并发保持 1，任务分钟错开；否则容易出现连续失败 → 24 小时暂停。
