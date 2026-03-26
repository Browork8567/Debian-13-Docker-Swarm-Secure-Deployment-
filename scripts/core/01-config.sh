#!/bin/bash
set -euo pipefail

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

# -------------------------------
# NAS CONFIG
# -------------------------------
read -rp "Do you want to configure NAS storage? (y/n): " NAS_ENABLE

NAS_IP=""
NAS_SHARE=""
NAS_PATH=""
NAS_USER=""
NAS_PASS=""
NAS_UID=""
NAS_GID=""

if [[ "$NAS_ENABLE" =~ ^[Yy]$ ]]; then
    read -rp "Enter NAS IP address: " NAS_IP
    read -rp "Enter NAS share name (e.g. media): " NAS_SHARE
    read -rp "Enter local mount path (e.g. /mnt/media): " NAS_PATH
    read -rp "Enter NAS username (service account recommended): " NAS_USER
    read -rsp "Enter NAS password: " NAS_PASS
    echo

    echo "[INFO] Configure UID/GID for container compatibility"
    read -rp "Enter UID (e.g. 1000): " NAS_UID
    read -rp "Enter GID (e.g. 1000): " NAS_GID
fi

# -------------------------------
# STORE CREDENTIALS SECURELY
# -------------------------------
if [[ "$NAS_ENABLE" =~ ^[Yy]$ ]]; then
    echo "[INFO] Storing NAS credentials securely..."

    CRED_FILE="/root/.nas-cred"

    cat > "$CRED_FILE" <<EOF
username=$NAS_USER
password=$NAS_PASS
EOF

    chmod 600 "$CRED_FILE"
fi

# -------------------------------
# SAFE JSON HELPER
# -------------------------------
json_value() {
    if [[ -z "$1" ]]; then
        echo null
    else
        echo "\"$1\""
    fi
}

# -------------------------------
# WRITE CONFIG
# -------------------------------
cat > "$CONFIG_FILE" <<EOF
{
  "role": $(json_value "$ROLE"),
  "node_ip": $(json_value "$NODE_IP"),
  "admin_user": $(json_value "$ADMIN_USER"),
  "admin_ip": $(json_value "$ADMIN_IP"),
  "is_primary_manager": $IS_PRIMARY_MANAGER,
  "nas_ip": $(json_value "$NAS_IP"),
  "nas_share": $(json_value "$NAS_SHARE"),
  "nas_path": $(json_value "$NAS_PATH"),
  "nas_user": $(json_value "$NAS_USER"),
  "nas_uid": $(json_value "$NAS_UID"),
  "nas_gid": $(json_value "$NAS_GID")
}
EOF

# -------------------------------
# VALIDATE CONFIG
# -------------------------------
if ! jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
    echo "[ERROR] Invalid config.json generated:"
    cat "$CONFIG_FILE"
    exit 1
fi
# -------------------------------
# Generate nas mount point
# -------------------------------

if [[ -n "$NAS_PATH" ]]; then
    echo "[INFO] Creating mount directory $NAS_PATH"
    mkdir -p "$NAS_PATH"
fi

echo "[INFO] Configuration saved to $CONFIG_FILE"