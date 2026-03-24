#!/usr/bin/env bash
set -euo pipefail

source /opt/swarm-secure/config.env

CURRENT_USER=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")

HOST=$(hostname)

if docker info 2>/dev/null | grep -q "Swarm: active"; then
  exit 0
fi

if [[ "$HOST" == "mgr-01" ]]; then
  IP=$(hostname -I | awk '{print $1}')
  docker swarm init --advertise-addr "$IP"
else
  while true; do
    if ssh -o BatchMode=yes "$CURRENT_USER@$PRIMARY_MANAGER" "docker info" >/dev/null 2>&1; then
      TOKEN=$(ssh "$CURRENT_USER@$PRIMARY_MANAGER" docker swarm join-token -q manager)
      docker swarm join --token "$TOKEN" "$PRIMARY_IP:2377"
      break
    fi
    sleep 3
  done
fi

echo "[07] Swarm ready."