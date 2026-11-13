#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/demo/clash-proxy/config}"
IMAGE="${IMAGE:-clash-proxy-manager:latest}"

docker rm -f clash-proxy-demo >/dev/null 2>&1 || true

docker run -d \
  --name clash-proxy-demo \
  --network host \
  --restart no \
  -e MIHOMO_MIXED_PORT="${MIHOMO_MIXED_PORT:-7900}" \
  -e DASHBOARD_PORT="${DASHBOARD_PORT:-8085}" \
  -e PORT_START="${PORT_START:-10001}" \
  -e MIHOMO_CONTROLLER="${MIHOMO_CONTROLLER:-127.0.0.1:9093}" \
  -e MIHOMO_API="${MIHOMO_API:-}" \
  -e GATE_HOST_IP="${GATE_HOST_IP:-}" \
  -v "$CONFIG_DIR:/root/.config/mihomo" \
  "$IMAGE"

docker ps --filter name=clash-proxy-demo
