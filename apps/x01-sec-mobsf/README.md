# x01-sec-mobsf

> WSL2 `wsl-x` 仓库 · `app/x01-sec-mobsf` 分支。真实凭据、数据、镜像不入库。

| 项 | 值 |
|---|---|
| 类型 | Docker Compose（infra `sec/mobsf`） |
| 状态（2026-11-13） | Exited (0)，2026-11-09 手动停 |
| 真实路径 | WSL `~/infra/sec/mobsf/`（`compose.yaml`、`.env`、`data/`） |
| 镜像 | `opensecurity/mobile-security-framework-mobsf:latest`（3.5 GB） |
| 端口 | `8000 -> 8000`（`0.0.0.0`） |
| 数据 | `~/infra/sec/mobsf/data`（uid 9901） |
| 网络 | `x01-sec-mobsf_default` |
| 重启 | unless-stopped |
| 凭据 | `.env` 的 `MOBSF_API_KEY`；Web 默认 `mobsf/mobsf`，应改 |

## 组成

- 单容器 MobSF，移动应用静态/动态分析；上传 APK 与扫描结果都在 `data/`。
- 默认 Web 账号 `mobsf/mobsf` 只适合本机；暴露局域网前必须改。
- 动态分析需要 `MOBSF_ANALYZER_IDENTIFIER` 指向 adb 设备。

## 配置

| 文件 | 说明 |
|---|---|
| `compose.yaml` | 实际 compose |
| `env.example` | API key 与分析器标识 |

## 启停

```bash
~/infra/bin/x01 up sec/mobsf
~/infra/bin/x01 down sec/mobsf
docker compose -f ~/infra/sec/mobsf/compose.yaml up -d
```

## 健康检查

```bash
docker ps -a --filter name=x01-sec-mobsf
curl -fsS http://127.0.0.1:8000/ >/dev/null && echo ok
docker logs --tail 100 x01-sec-mobsf
```

访问：`http://wsl.x01:8000/`。

## 备份 / 恢复

```bash
mkdir -p ~/infra/backup
tar czf ~/infra/backup/mobsf-$(date +%F).tgz -C ~/infra/sec/mobsf data
```

## 注意

- 数据目录 uid 9901；换机时搬 `data/` 即可保留历史扫描。
- 镜像 3.5 GB，清理前确认没有运行中的扫描。
- API 示例：`curl -F 'file=@app.apk' -H "Authorization: $MOBSF_API_KEY" http://127.0.0.1:8000/api/v1/upload`

## 关联

- `main`：`system/03-容器服务清单.md`、`system/08-协调与调度.md`
- 目录总表：`main` 分支的 `apps/README.md`
