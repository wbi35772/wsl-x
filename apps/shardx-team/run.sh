#!/usr/bin/env bash
set -euo pipefail

VOLUME="${VOLUME:-shardx-team-data}"
IMAGE="${IMAGE:-ghcr.io/proxyshard/shardbrowser-team-server:latest}"

docker volume create "$VOLUME" >/dev/null
docker rm -f shardx-team >/dev/null 2>&1 || true

docker run -d \
  --name shardx-team \
  -p 8787:8787 \
  --restart no \
  -v "$VOLUME:/data" \
  -e SHARDBROWSER_TEAM_NAME="${SHARDBROWSER_TEAM_NAME:-CHANGE_ME}" \
  -e SHARDBROWSER_TEAM_BIND="${SHARDBROWSER_TEAM_BIND:-0.0.0.0:8787}" \
  -e SHARDBROWSER_TEAM_PUBLIC_URL="${SHARDBROWSER_TEAM_PUBLIC_URL:-http://wsl.x01:8787}" \
  -e SHARDBROWSER_TEAM_DATA_DIR="${SHARDBROWSER_TEAM_DATA_DIR:-/data}" \
  -e RUST_LOG="${RUST_LOG:-info}" \
  "$IMAGE"

docker ps --filter name=shardx-team
