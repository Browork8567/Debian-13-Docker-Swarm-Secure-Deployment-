#!/bin/bash

NODES="/etc/swarm-bootstrap/nodes.json"
CONFIG="/etc/swarm-bootstrap/config.json"

[[ ! -f "$NODES" ]] && exit 0

ADMIN_IP=$(jq -r .admin_ip "$CONFIG")

echo "[INFO] Syncing UFW rules..."

# Ensure admin access remains
ufw allow from "$ADMIN_IP" to any port 22

# Allow managers
for IP in $(jq -r '.managers[]' "$NODES"); do
    ufw allow from "$IP" to any port 22
done

# Swarm ports
ufw allow 2377/tcp
ufw allow 7946/tcp
ufw allow 7946/udp
ufw allow 4789/udp

echo "[INFO] UFW sync complete"