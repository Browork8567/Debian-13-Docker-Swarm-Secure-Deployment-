#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/swarm-bootstrap/config.json"
INIT_FLAG="/etc/swarm-bootstrap/.initialized"

echo "[07] Configuring Docker Swarm..."

# -------------------------------
# VALIDATE CONFIG
# -------------------------------
if [[ ! -f "$CONFIG" ]]; then
    echo "[ERROR] Missing config.json"
    exit 1
fi

ROLE=$(jq -r .role "$CONFIG")
NODE_IP=$(jq -r .node_ip "$CONFIG")
IS_PRIMARY=$(jq -r .is_primary_manager "$CONFIG")
BOOTSTRAP_USER=$(jq -r .bootstrap_user "$CONFIG")

CURRENT_USER=$(whoami)

# -------------------------------
# PRIMARY MANAGER INIT
# -------------------------------
if [[ "$ROLE" == "manager" && "$IS_PRIMARY" == "true" ]]; then

    echo "[INFO] Node is PRIMARY manager"

    # -------------------------------
    # ENSURE sshpass EXISTS
    # -------------------------------
    if ! command -v sshpass >/dev/null 2>&1; then
        echo "[INFO] Installing sshpass (required for discovery)..."
        apt-get update -y
        apt-get install -y sshpass
    else
        echo "[INFO] sshpass already installed"
    fi

    # -------------------------------
    # INIT SWARM (IDEMPOTENT)
    # -------------------------------
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        echo "[INFO] Swarm already initialized"
    else
        echo "[INFO] Initializing swarm..."
        docker swarm init --advertise-addr "$NODE_IP"
    fi

    # -------------------------------
    # MARK INITIALIZED
    # -------------------------------
    mkdir -p /etc/swarm-bootstrap
    touch "$INIT_FLAG"

    echo "[INFO] Primary manager ready"

    # -------------------------------
    # REMOVE BOOTSTRAP USER (SAFE)
    # -------------------------------
    if id "$BOOTSTRAP_USER" >/dev/null 2>&1; then
        if [[ "$CURRENT_USER" != "$BOOTSTRAP_USER" ]]; then
            echo "[INFO] Removing bootstrap user on leader..."
            userdel -r "$BOOTSTRAP_USER" || echo "[WARN] Failed to remove bootstrap user"
        else
            echo "[WARN] Skipping bootstrap user removal (current session user)"
        fi
    else
        echo "[INFO] Bootstrap user already removed"
    fi

    exit 0
fi

# -------------------------------
# NON-PRIMARY NODES (PASSIVE MODE)
# -------------------------------
echo "[INFO] Node is NOT primary manager"

echo "[INFO] Preparing node for discovery-based join..."

# Ensure Docker is running
if ! systemctl is-active --quiet docker; then
    echo "[INFO] Starting Docker..."
    systemctl start docker
fi

# Ensure not already in swarm
if docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo "[INFO] Node already part of a swarm"
else
    echo "[INFO] Node ready to be discovered and joined by leader"
fi

# -------------------------------
# OPTIONAL: CLEANUP BOOTSTRAP USER (DEFERRED)
# -------------------------------
# NOTE:
# Do NOT remove bootstrap user here yet.
# Leader will remove it after provisioning.
# This avoids cutting off access mid-discovery.

echo "[07] Swarm preparation complete."