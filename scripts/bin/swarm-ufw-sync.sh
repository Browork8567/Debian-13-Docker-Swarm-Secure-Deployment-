#!/bin/bash

CONFIG="/etc/swarm-bootstrap/config.json"
NODES="/etc/swarm-bootstrap/nodes.json"

ROLE=$(jq -r .role "$CONFIG")

# Only managers update UFW inbound
if [[ "$ROLE" != "manager" ]]; then
    echo "[INFO] Not a manager, skipping UFW sync"
    exit 0
fi

[[ ! -f "$NODES" ]] && exit 0

ADMIN_IP=$(jq -r .admin_ip "$CONFIG")

echo "[INFO] Syncing UFW rules..."

# Ensure admin access
ufw allow from "$ADMIN_IP" to any port 22

# Allow manager IPs
for IP in $(jq -r '.managers[]' "$NODES"); do
    ufw allow from "$IP" to any port 22
done

# Swarm ports
ufw allow 2377/tcp
ufw allow 7946/tcp
ufw allow 7946/udp
ufw allow 4789/udp

echo "[INFO] UFW sync complete"