#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/swarm-bootstrap/config.json"
NODES="/etc/swarm-bootstrap/nodes.json"

[[ ! -f "$CONFIG" ]] && exit 0
[[ ! -f "$NODES" ]] && exit 0

ROLE=$(jq -r .role "$CONFIG")

# Only managers update UFW inbound
if [[ "$ROLE" != "manager" ]]; then
    echo "[INFO] Not a manager, skipping UFW sync"
    exit 0
fi

ADMIN_IP=$(jq -r .admin_ip "$CONFIG")

echo "[INFO] Syncing UFW rules..."

# Admin access
if [[ "$ADMIN_IP" != "null" && -n "$ADMIN_IP" ]]; then
    ufw allow from "$ADMIN_IP" to any port 22
fi

# Manager access
for IP in $(jq -r '.managers[]' "$NODES"); do
    ufw allow from "$IP" to any port 22
done

# Swarm ports (safe to reapply)
ufw allow 2377/tcp
ufw allow 7946/tcp
ufw allow 7946/udp
ufw allow 4789/udp

echo "[INFO] UFW sync complete"