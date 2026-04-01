#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="/etc/swarm-bootstrap"
CONFIG_FILE="$CONFIG_DIR/config.json"

USER_CONFIG_DIR="$HOME/.swarm-bootstrap"
USER_CONFIG_FILE="$USER_CONFIG_DIR/config.json"

mkdir -p "$CONFIG_DIR"
mkdir -p "$USER_CONFIG_DIR"

# -------------------------------
# REUSE EXISTING CONFIG
# -------------------------------
if [[ -f "$CONFIG_FILE" ]]; then
    echo "[INFO] Existing config detected, skipping prompts"
    exit 0
fi

echo "[INFO] Starting interactive configuration..."

# -------------------------------
# AUTO-DETECT NODE IP
# -------------------------------
NODE_IP=$(hostname -I | awk '{print $1}')
echo "[INFO] Detected IP: $NODE_IP"

read -rp "Enter admin username: " ADMIN_USER
read -rp "Enter admin IP address: " ADMIN_IP


# -------------------------------
# LEADER SELECTION
# -------------------------------
read -rp "Is this the LEADER node? (y/n): " IS_LEADER_INPUT
IS_LEADER=false
if [[ "$IS_LEADER_INPUT" =~ ^[Yy]$ ]]; then
    IS_LEADER=true
fi

PRIMARY_MANAGER_IP=""
MANAGER_RANGE=()
WORKER_RANGE=()

if [[ "$IS_LEADER" == "true" ]]; then
    PRIMARY_MANAGER_IP="$NODE_IP"
    echo "[INFO] Setting primary manager IP to local node: $PRIMARY_MANAGER_IP"

    echo "[INFO] Enter manager node IPs (space separated)"
    echo "Example: 192.168.69.10 192.168.69.11 192.168.69.12"
    read -rp "Manager IPs: " -a MANAGER_RANGE

    echo "[INFO] Enter worker node IPs (space separated)"
    echo "Example: 192.168.70.10 192.168.70.11"
    read -rp "Worker IPs: " -a WORKER_RANGE

else
    read -rp "Enter PRIMARY manager IP: " PRIMARY_MANAGER_IP
fi
# -------------------------------
# BOOTSTRAP USER PASSWORD
# -------------------------------
BOOTSTRAP_USER="bootstrap"

if [[ "$IS_LEADER" == "true" ]]; then
    echo "[INFO] Leader node must define bootstrap password"

    read -rsp "Enter bootstrap password: " BOOTSTRAP_PASS
    echo
    read -rsp "Confirm bootstrap password: " BOOTSTRAP_PASS_CONFIRM
    echo

    if [[ "$BOOTSTRAP_PASS" != "$BOOTSTRAP_PASS_CONFIRM" ]]; then
        echo "[ERROR] Passwords do not match"
        exit 1
    fi
else
    echo "[INFO] Enter bootstrap password provided by leader"
    read -rsp "Bootstrap password: " BOOTSTRAP_PASS
    echo
fi

# Hash password
BOOTSTRAP_PASS_HASH=$(openssl passwd -6 "$BOOTSTRAP_PASS")

# -------------------------------
# NAS CONFIG
# -------------------------------
read -rp "Do you want to configure NAS storage? (y/n): " NAS_ENABLE

NAS_IP=""
NAS_SHARE=""
NAS_PATH=""
NAS_UID=""
NAS_GID=""

if [[ "$NAS_ENABLE" =~ ^[Yy]$ ]]; then
    read -rp "Enter NAS IP address: " NAS_IP
    read -rp "Enter NAS share name: " NAS_SHARE
    read -rp "Enter mount path (e.g. /mnt/media): " NAS_PATH

    echo "[INFO] UID/GID for container access"
    read -rp "UID: " NAS_UID
    read -rp "GID: " NAS_GID
fi

# -------------------------------
# JSON HELPER
# -------------------------------
json_val() {
    [[ -z "$1" ]] && echo null || echo "\"$1\""
}

# -------------------------------
# WRITE SYSTEM CONFIG (SAFE)
# -------------------------------
cat > "$CONFIG_FILE" <<EOF
{
  "node_ip": "$NODE_IP",
  "admin_user": "$ADMIN_USER",
  "admin_ip": "$ADMIN_IP",

  "is_leader": $IS_LEADER,
  "primary_manager_ip": "$PRIMARY_MANAGER_IP",

  "manager_range": $(printf '%s\n' "${MANAGER_RANGE[@]}" | jq -R . | jq -s .),
  "worker_range": $(printf '%s\n' "${WORKER_RANGE[@]}" | jq -R . | jq -s .),

  "bootstrap_user": "$BOOTSTRAP_USER",
  "bootstrap_pass_hash": "$BOOTSTRAP_PASS_HASH",

  "nas_ip": $(json_val "$NAS_IP"),
  "nas_share": $(json_val "$NAS_SHARE"),
  "nas_path": $(json_val "$NAS_PATH"),
  "nas_uid": $(json_val "$NAS_UID"),
  "nas_gid": $(json_val "$NAS_GID")
}
EOF

# Validate JSON
if ! jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
    echo "[ERROR] Invalid config.json generated"
    cat "$CONFIG_FILE"
    exit 1
fi

# -------------------------------
# WRITE USER CONFIG (WITH SECRET)
# -------------------------------
cat > "$USER_CONFIG_FILE" <<EOF
{
  "node_ip": "$NODE_IP",
  "primary_manager_ip": "$PRIMARY_MANAGER_IP",

  "bootstrap_user": "$BOOTSTRAP_USER",
  "bootstrap_password": "$BOOTSTRAP_PASS",

  "manager_subnet": "$MANAGER_SUBNET",
  "worker_subnet": "$WORKER_SUBNET"
}
EOF

chmod 600 "$USER_CONFIG_FILE"

echo "[INFO] Configuration saved:"
echo " - System: $CONFIG_FILE"
echo " - User:   $USER_CONFIG_FILE"