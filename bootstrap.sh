#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/swarm-bootstrap.log"
mkdir -p /var/log
touch "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "[INFO] Starting Swarm Bootstrap..."

########################################
# PRE-FLIGHT: Ensure jq is installed
########################################

echo "[INFO] Checking for jq..."

if command -v jq >/dev/null 2>&1; then
    echo "[INFO] jq already installed"
else
    echo "[WARN] jq is required to continue."
    read -rp "Install jq now? (y/n): " INSTALL_JQ

    if [[ "$INSTALL_JQ" =~ ^[Yy]$ ]]; then
        echo "[INFO] Installing jq..."

        apt-get update
        apt-get install -y jq

        if command -v jq >/dev/null 2>&1; then
            echo "[INFO] jq installation successful"
        else
            echo "[ERROR] jq installation failed. Exiting."
            exit 1
        fi
    else
        echo "[ERROR] jq is required. Exiting."
        exit 1
    fi
fi

########################################
# Ensure config directory exists
########################################

mkdir -p /etc/swarm-bootstrap

########################################
# Run scripts in order
########################################

for script in scripts/core/*.sh; do
    echo "[INFO] Running $script"
    bash "$script"
done

########################################
# Final role output (safe)
########################################

if [[ -f /etc/swarm-bootstrap/config.json ]]; then
    ROLE=$(jq -r .role /etc/swarm-bootstrap/config.json)
else
    ROLE="unknown"
fi

echo "[INFO] Bootstrap complete for role: $ROLE"