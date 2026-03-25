#!/bin/bash
set -e

CONFIG="/etc/swarm-bootstrap/config.json"

ADMIN_USER=$(jq -r .admin_user "$CONFIG")
MANAGERS=$(jq -r '.managers[]' "$CONFIG")

echo "[INFO] Configuring SSH trust..."

PUB_KEY=$(cat /home/swarmd/.ssh/id_rsa.pub)

for HOST in $MANAGERS; do
    echo "[INFO] Setting up SSH on $HOST"

    # Ensure swarmd user + ssh dir exists
    ssh "$ADMIN_USER@$HOST" "sudo mkdir -p /home/swarmd/.ssh && sudo chown -R swarmd:swarmd /home/swarmd/.ssh"

    # Write restricted key ONLY (overwrite to prevent duplicates)
    ssh "$ADMIN_USER@$HOST" "echo 'no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-pty $PUB_KEY' | sudo tee /home/swarmd/.ssh/authorized_keys > /dev/null"

    # Fix permissions
    ssh "$ADMIN_USER@$HOST" "sudo chmod 700 /home/swarmd/.ssh && sudo chmod 600 /home/swarmd/.ssh/authorized_keys && sudo chown -R swarmd:swarmd /home/swarmd/.ssh"
done

echo "[INFO] SSH trust configured"