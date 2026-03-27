#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Setting up runtime services..."

SYSTEMD_DEST="/etc/systemd/system"
BIN_DEST="/usr/local/bin"
CONFIG="/etc/swarm-bootstrap/config.json"

SCRIPT_SOURCE_DIR="./scripts/bin"
SYSTEMD_SOURCE_DIR="./systemd"

# -------------------------------
# VALIDATE CONFIG
# -------------------------------
if [[ ! -f "$CONFIG" ]]; then
    echo "[ERROR] Missing config.json"
    exit 1
fi

IS_PRIMARY=$(jq -r .is_primary_manager "$CONFIG")

# -------------------------------
# INSTALL RUNTIME SCRIPTS
# -------------------------------
echo "[INFO] Installing runtime scripts..."

RUNTIME_SCRIPTS=(
swarm-health.sh
swarm-manager-sync.sh
swarm-ufw-sync.sh
swarm-discovery.sh
)

for script in "${RUNTIME_SCRIPTS[@]}"; do
    if [[ -f "$SCRIPT_SOURCE_DIR/$script" ]]; then
        install -m 755 "$SCRIPT_SOURCE_DIR/$script" "$BIN_DEST/$script"
        echo "[INFO] Installed $script"
    else
        echo "[WARN] Missing $script"
    fi
done

# -------------------------------
# COPY SYSTEMD UNITS
# -------------------------------
echo "[INFO] Copying systemd unit files..."

SYSTEMD_UNITS=(
swarm-health.service
swarm-health.timer
swarm-manager-sync.service
swarm-manager-sync.timer
swarm-ufw-sync.service
swarm-ufw-sync.timer
swarm-discovery.service
swarm-discovery.timer
)

for unit in "${SYSTEMD_UNITS[@]}"; do
    if [[ -f "$SYSTEMD_SOURCE_DIR/$unit" ]]; then
        cp "$SYSTEMD_SOURCE_DIR/$unit" "$SYSTEMD_DEST/"
        echo "[INFO] Copied $unit"
    else
        echo "[WARN] Missing $unit"
    fi
done

# -------------------------------
# RELOAD SYSTEMD
# -------------------------------
echo "[INFO] Reloading systemd..."
systemctl daemon-reexec
systemctl daemon-reload

# -------------------------------
# ENABLE BASE TIMERS (ALL NODES)
# -------------------------------
BASE_TIMERS=(
swarm-health.timer
swarm-manager-sync.timer
swarm-ufw-sync.timer
)

for timer in "${BASE_TIMERS[@]}"; do
    systemctl enable --now "$timer"
    echo "[INFO] Enabled $timer"
done

# -------------------------------
# ENABLE DISCOVERY (LEADER ONLY)
# -------------------------------
if [[ "$IS_PRIMARY" == "true" ]]; then
    echo "[INFO] Enabling swarm discovery (leader only)..."
    systemctl enable --now swarm-discovery.timer
    echo "[INFO] swarm-discovery.timer enabled"
else
    echo "[INFO] Not primary manager, skipping discovery service"
fi

echo "[INFO] Runtime services configured."