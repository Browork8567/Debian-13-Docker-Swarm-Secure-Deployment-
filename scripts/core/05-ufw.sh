#!/bin/bash
set -e

echo "[INFO] Configuring UFW..."

apt-get install -y ufw

ufw default deny incoming
ufw default allow outgoing

# ALWAYS allow SSH before rules
ufw allow OpenSSH

ADMIN_IP=$(jq -r .admin_ip /etc/swarm-bootstrap/config.json)

if [[ "$ADMIN_IP" != "null" ]]; then
    ufw allow from "$ADMIN_IP" to any port 22
fi

# Swarm ports
ufw allow 2377/tcp
ufw allow 7946/tcp
ufw allow 7946/udp
ufw allow 4789/udp

ufw --force enable

echo "[INFO] UFW configured."