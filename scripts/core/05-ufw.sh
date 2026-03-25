#!/bin/bash
set -e

CONFIG="/etc/swarm-bootstrap/config.json"

ADMIN_IP=$(jq -r .admin_ip "$CONFIG")

echo "[INFO] Configuring UFW..."

apt-get install -y ufw

ufw default deny incoming
ufw default allow outgoing

# SSH ONLY from admin
ufw allow from "$ADMIN_IP" to any port 22

# Swarm ports
ufw allow 2377/tcp
ufw allow 7946/tcp
ufw allow 7946/udp
ufw allow 4789/udp

ufw --force enable

echo "[INFO] UFW configured"