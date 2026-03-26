#!/bin/bash
set -e

CONFIG_DIR="/etc/swarm-bootstrap"
CONFIG_FILE="$CONFIG_DIR/config.json"

mkdir -p "$CONFIG_DIR"

echo "[INFO] Starting interactive configuration..."

read -rp "Enter node role (manager/worker): " ROLE
read -rp "Enter node IP address: " NODE_IP
read -rp "Enter admin username: " ADMIN_USER
read -rp "Enter admin IP address: " ADMIN_IP

IS_PRIMARY_MANAGER=false

if [[ "$ROLE" == "manager" ]]; then
    read -rp "Is this the PRIMARY manager node? (y/n): " PRIMARY_INPUT
    if [[ "$PRIMARY_INPUT" =~ ^[Yy]$ ]]; then
        IS_PRIMARY_MANAGER=true
    fi
fi

read -rp "Do you want to configure NAS storage? (y/n): " NAS_ENABLE

NAS_IP=null
NAS_PATH=null
NAS_USER=null

if [[ "$NAS_ENABLE" =~ ^[Yy]$ ]]; then
    read -rp "Enter NAS IP address: " NAS_IP
    read -rp "Enter NAS mount path (e.g. /mnt/storage): " NAS_PATH
    read -rp "Enter NAS username: " NAS_USER
fi

cat > "$CONFIG_FILE" <<EOF
{
  "role": "$ROLE",
  "node_ip": "$NODE_IP",
  "admin_user": "$ADMIN_USER",
  "admin_ip": "$ADMIN_IP",
  "is_primary_manager": $IS_PRIMARY_MANAGER,
  "nas_ip": "$NAS_IP",
  "nas_path": "$NAS_PATH",
  "nas_user": "$NAS_USER"
}
EOF

echo "[INFO] Configuration saved to $CONFIG_FILE"