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

# -------------------------------
# HELPER: EXPAND IP INPUTS
# -------------------------------
expand_ips() {
    local input=$1
    local ips=()

    # CIDR subnet
    if [[ "$input" =~ / ]]; then
        if command -v nmap >/dev/null 2>&1; then
            mapfile -t ips < <(nmap -n -sL "$input" | awk '/Nmap scan report/{print $5}')
        else
            echo "[ERROR] nmap is required to expand CIDR subnets"
            exit 1
        fi
    # Range format, e.g., 192.168.69.10-12
    elif [[ "$input" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.([0-9]+)-([0-9]+)$ ]]; then
        base="${BASH_REMATCH[1]}"
        start="${BASH_REMATCH[2]}"
        end="${BASH_REMATCH[3]}"
        for i in $(seq "$start" "$end"); do
            ips+=("$base.$i")
        done
    # Single IP or space-separated list
    else
        read -ra ips <<<"$input"
    fi

    echo "${ips[@]}"
}

# -------------------------------
# ENTER MANAGER AND WORKER NODES
# -------------------------------
if [[ "$IS_LEADER" == "true" ]]; then
    PRIMARY_MANAGER_IP="$NODE_IP"
    echo "[INFO] Setting primary manager IP to local node: $PRIMARY_MANAGER_IP"

    echo "[INFO] Enter manager node IPs"
    echo "Examples:"
    echo " - Single IP: 192.168.69.10"
    echo " - List of IPs: 192.168.69.10 192.168.69.11 192.168.69.12"
    echo " - Range: 192.168.69.10-12"
    echo " - Subnet: 192.168.69.0/28"
    read -rp "Manager IPs: " MANAGER_INPUT
    MANAGER_RANGE=($(expand_ips "$MANAGER_INPUT"))

    echo "[INFO] Enter worker node IPs"
    echo "Examples:"
    echo " - Single IP: 192.168.70.10"
    echo " - List of IPs: 192.168.70.10 192.168.70.11"
    echo " - Range: 192.168.70.10-11"
    echo " - Subnet: 192.168.70.0/28"
    read -rp "Worker IPs: " WORKER_INPUT
    WORKER_RANGE=($(expand_ips "$WORKER_INPUT"))
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
# WRITE USER CONFIG (WITH SECRET)
# -------------------------------
MANAGER_JSON=$(printf '%s\n' "${MANAGER_RANGE[@]}" | jq -R . | jq -s .)
WORKER_JSON=$(printf '%s\n' "${WORKER_RANGE[@]}" | jq -R . | jq -s .)

if [[ -n "$NAS_IP" ]]; then
    NAS_JSON=$(jq -n \
        --arg ip "$NAS_IP" \
        --arg share "$NAS_SHARE" \
        --arg path "$NAS_PATH" \
        --arg uid "$NAS_UID" \
        --arg gid "$NAS_GID" \
        '{ip: $ip, share: $share, path: $path, uid: $uid, gid: $gid}')
else
    NAS_JSON="null"
fi

cat > "$USER_CONFIG_FILE" <<EOF
{
  "node_ip": "$NODE_IP",
  "primary_manager_ip": "$PRIMARY_MANAGER_IP",

  "bootstrap_user": "$BOOTSTRAP_USER",
  "bootstrap_password": "$BOOTSTRAP_PASS",

  "manager_nodes": $MANAGER_JSON,
  "worker_nodes": $WORKER_JSON,

  "nas": $NAS_JSON
}
EOF

chmod 600 "$USER_CONFIG_FILE"

echo "[INFO] Configuration saved:"
echo " - System: $CONFIG_FILE"
echo " - User:   $USER_CONFIG_FILE"