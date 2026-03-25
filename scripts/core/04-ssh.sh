#!/bin/bash
set -e

CONFIG="/etc/swarm-bootstrap/config.json"

ADMIN_USER=$(jq -r .admin_user "$CONFIG")
MANAGERS=$(jq -r '.managers[]' "$CONFIG")

echo "[INFO] Configuring SSH trust..."

PUB_KEY=$(cat /home/swarmd/.ssh/id_rsa.pub)

for HOST in $MANAGERS; do
    echo "[INFO] Adding key to $HOST"

    ssh "$ADMIN_USER@$HOST" "mkdir -p ~/.ssh && echo '$PUB_KEY' >> ~/.ssh/authorized_keys"

    ssh "$ADMIN_USER@$HOST" "echo 'no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-pty $PUB_KEY' >> /home/swarmd/.ssh/authorized_keys" || true
done