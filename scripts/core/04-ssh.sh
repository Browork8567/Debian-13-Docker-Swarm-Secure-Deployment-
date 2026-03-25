#!/bin/bash
set -e

echo "[INFO] Setting up SSH for swarmd..."

SSH_DIR="/home/swarmd/.ssh"
KEY_FILE="$SSH_DIR/id_rsa"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ ! -f "$KEY_FILE" ]]; then
    ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N ""
fi

chmod 600 "$KEY_FILE"
chmod 644 "$KEY_FILE.pub"
chown -R swarmd:swarmd "$SSH_DIR"

# Load manager list
MANAGERS=$(jq -r '.managers[]?' /etc/swarm-bootstrap/nodes.json || true)

for NODE in $MANAGERS; do
    echo "[INFO] Syncing SSH key to $NODE"

    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$NODE" \
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh"

    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$NODE" \
        "grep -qxF '$(cat $KEY_FILE.pub)' ~/.ssh/authorized_keys || \
        echo 'no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-pty $(cat $KEY_FILE.pub)' >> ~/.ssh/authorized_keys"
done

echo "[INFO] SSH setup complete."