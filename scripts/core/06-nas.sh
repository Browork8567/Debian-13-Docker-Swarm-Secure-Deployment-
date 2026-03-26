#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/swarm-bootstrap/config.json"

if [[ ! -f "$CONFIG" ]]; then
    echo "[WARN] Config file not found, skipping NAS setup"
    exit 0
fi

echo "[05] Mounting NAS (optional)..."

mkdir -p /data

if ! grep -q "$NAS_IP" /etc/fstab; then
  echo "# TODO: Add your secure NAS mount here using credentials file"
fi

mount -a || true

echo "[05] NAS step complete (non-blocking)."