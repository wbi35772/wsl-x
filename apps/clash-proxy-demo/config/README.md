# config/

真实目录 `~/demo/clash-proxy/config`，挂到容器的 `/root/.config/mihomo`。

包含：

- `config.yaml` 与历史 `config.yaml.bak-*`
- `cache.db`、`geoip.metadb`、`geoip.mmdb`、`geosite.dat`
- `subscriptions.json`、`proxy_groups.json`、`ip_quality.json`
- `backups/`、`flags/`

订阅地址、密钥与缓存均不入库；恢复时从宿主备份取回整个 `config/`。
