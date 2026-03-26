#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Configuring UFW..."

# Ensure jq exists
if ! command -v jq >/dev/null 2>&1; then
    echo "[ERROR] jq is required but not installed"
    exit 1
fi

apt-get update
apt-get install -y ufw

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Always allow SSH first (safety)
ufw allow OpenSSH

# Load admin IP safely
CONFIG="/etc/swarm-bootstrap/config.json"

if [[ ! -f "$CONFIG" ]]; then
    echo "[WARN] Config not found, skipping admin IP rule"
else
    ADMIN_IP=$(jq -r .admin_ip "$CONFIG")

    if [[ "$ADMIN_IP" != "null" && -n "$ADMIN_IP" ]]; then
        ufw allow from "$ADMIN_IP" to any port 22
    fi
fi

# Allow ALL swarm-related traffic initially (bootstrap-safe)
ufw allow 2377/tcp
ufw allow 7946/tcp
ufw allow 7946/udp
ufw allow 4789/udp

# Allow internal private ranges (cluster communication safety)
ufw allow from 10.0.0.0/8
ufw allow from 172.16.0.0/12
ufw allow from 192.168.0.0/16

# Enable firewall
ufw --force enable

echo "[INFO] UFW configured (initial permissive mode)."