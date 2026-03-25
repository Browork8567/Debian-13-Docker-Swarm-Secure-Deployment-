#!/usr/bin/env bash
set -euo pipefail

source /opt/swarm-secure/config.env

echo "[05] Mounting NAS (optional)..."

mkdir -p /data

if ! grep -q "$NAS_IP" /etc/fstab; then
  echo "# TODO: Add your secure NAS mount here using credentials file"
fi

mount -a || true

echo "[05] NAS step complete (non-blocking)."