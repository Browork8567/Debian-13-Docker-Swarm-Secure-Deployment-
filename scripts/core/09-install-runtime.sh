#!/bin/bash
set -euo pipefail

echo "[INFO] Setting up runtime services..."

# Paths
SYSTEMD_DIR="/etc/systemd/system"
BIN_DIR="/usr/local/bin"
REPO_DIR="$(dirname "$0")/../../systemd"   # systemd unit files in repo root
BIN_REPO_DIR="$(dirname "$0")/../bin"      # runtime scripts in repo under scripts/bin

# List of systemd units
SERVICES=(
    swarm-health.service
    swarm-health.timer
    swarm-manager-sync.service
    swarm-manager-sync.timer
    swarm-ufw-sync.service
    swarm-ufw-sync.timer
)

# Copy systemd unit files
echo "[INFO] Copying systemd unit files..."
for svc in "${SERVICES[@]}"; do
    if [[ -f "$REPO_DIR/$svc" ]]; then
        cp "$REPO_DIR/$svc" "$SYSTEMD_DIR/"
        echo "[INFO] Copied $svc to $SYSTEMD_DIR"
    else
        echo "[WARN] Missing $svc in repo folder $REPO_DIR"
    fi
done

# Copy runtime scripts (excluding docker-mount-guard.sh)
RUNTIME_SCRIPTS=(
    swarm-health.sh
    swarm-manager-sync.sh
    swarm-ufw-sync.sh
)

echo "[INFO] Installing runtime scripts..."
for script in "${RUNTIME_SCRIPTS[@]}"; do
    if [[ -f "$BIN_REPO_DIR/$script" ]]; then
        cp "$BIN_REPO_DIR/$script" "$BIN_DIR/"
        chmod +x "$BIN_DIR/$script"
        echo "[INFO] Installed $script to $BIN_DIR"
    else
        echo "[WARN] Missing runtime script $script in repo folder $BIN_REPO_DIR"
    fi
done

# Reload systemd daemon
echo "[INFO] Reloading systemd daemon..."
systemctl daemon-reexec
systemctl daemon-reload

# Enable and start timers/services
echo "[INFO] Enabling and starting systemd units..."
for svc in "${SERVICES[@]}"; do
    if [[ -f "$SYSTEMD_DIR/$svc" ]]; then
        systemctl enable --now "$svc"
        echo "[INFO] Enabled and started $svc"
    else
        echo "[WARN] Cannot enable missing $svc"
    fi
done

echo "[INFO] Runtime services configured successfully."