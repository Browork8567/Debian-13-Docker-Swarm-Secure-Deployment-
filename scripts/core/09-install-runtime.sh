#!/bin/bash
set -e

echo "[INFO] Setting up runtime services..."

SYSTEMD_DIR="/etc/systemd/system"

SERVICES=(
swarm-health.service
swarm-health.timer
swarm-manager-sync.service
swarm-manager-sync.timer
swarm-ufw-sync.service
swarm-ufw-sync.timer
docker-mount-guard.service
docker-mount-guard.timer
)

for svc in "${SERVICES[@]}"; do
    if [[ -f "$SYSTEMD_DIR/$svc" ]]; then
        systemctl enable --now "$svc"
    else
        echo "[WARN] Missing $svc"
    fi
done

echo "[INFO] Runtime services configured."