#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-/opt/net-egress}"
IMAGE="${IMAGE:-clash-proxy-manager:latest}"

docker rm -f net-egress >/dev/null 2>&1 || true

docker run -d \
  --name net-egress \
  --restart unless-stopped \
  -p 127.0.0.1:7891:7891 \
  -p 127.0.0.1:9099:9099 \
  -v "$CONFIG_DIR:/root/.config/mihomo" \
  --entrypoint /usr/local/bin/mihomo \
  "$IMAGE" -d /root/.config/mihomo

docker ps --filter name=net-egress
