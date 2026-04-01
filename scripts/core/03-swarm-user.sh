#!/bin/bash
set -euo pipefail

echo "[INFO] Creating swarmd service account..."

CONFIG="/etc/swarm-bootstrap/config.json"

# -------------------------------
# VALIDATE CONFIG
# -------------------------------
if [[ ! -f "$CONFIG" ]]; then
    echo "[ERROR] Missing config.json"
    exit 1
fi

CURRENT_IP=$(hostname -I | awk '{print $1}')
PRIMARY_IP=$(jq -r .primary_manager_ip "$CONFIG")

BOOTSTRAP_USER=$(jq -r .bootstrap_user "$CONFIG")
BOOTSTRAP_PASS=$(jq -r .bootstrap_password "$CONFIG")

# -------------------------------
# CREATE SWARMD USER (ALWAYS)
# -------------------------------
if id -u swarmd >/dev/null 2>&1; then
    echo "[INFO] swarmd user already exists"
else
    useradd -r -m -d /home/swarmd -s /usr/sbin/nologin swarmd
    echo "[INFO] swarmd user created"
fi

# -------------------------------
# ENSURE GROUP EXISTS
# -------------------------------
if getent group swarmd >/dev/null 2>&1; then
    echo "[INFO] swarmd group already exists"
else
    echo "[INFO] Creating swarmd group..."
    groupadd -r swarmd
    usermod -aG swarmd swarmd || true
    echo "[INFO] swarmd group created and assigned"
fi

# -------------------------------
# ENSURE HOME + SSH DIR
# -------------------------------
HOME_DIR="/home/swarmd"
SSH_DIR="$HOME_DIR/.ssh"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chown -R swarmd:swarmd "$HOME_DIR"

# -------------------------------
# SSH KEY HANDLING (LEADER ONLY)
# -------------------------------
if [[ "$CURRENT_IP" == "$PRIMARY_IP" ]]; then
    echo "[INFO] Leader node detected — ensuring SSH key exists"

    if [[ ! -f "$SSH_DIR/id_rsa" ]]; then
        echo "[INFO] Generating SSH key for swarmd..."
        sudo -u swarmd ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/id_rsa" -N ""
    else
        echo "[INFO] SSH key already exists"
    fi

    chmod 600 "$SSH_DIR/id_rsa"
    chmod 644 "$SSH_DIR/id_rsa.pub"
    chown swarmd:swarmd "$SSH_DIR/id_rsa" "$SSH_DIR/id_rsa.pub"
else
    echo "[INFO] Non-leader node — skipping SSH key generation"
fi

# -------------------------------
# AUTHORIZED KEYS FILE
# -------------------------------
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"
chown swarmd:swarmd "$AUTHORIZED_KEYS"

# -------------------------------
# OPTIONAL: DOCKER ACCESS
# -------------------------------
if getent group docker >/dev/null; then
    usermod -aG docker swarmd
    echo "[INFO] swarmd added to docker group"
else
    echo "[WARN] docker group not found"
fi

# -------------------------------
# VALIDATE DOCKER ACCESS
# -------------------------------
echo "[INFO] Validating swarmd docker access..."

if sudo -u swarmd docker info >/dev/null 2>&1; then
    echo "[INFO] swarmd can access docker"
else
    echo "[WARN] swarmd docker access pending (normal until session refresh)"
fi

echo "[INFO] swarmd account ready"

# =========================================================
# BOOTSTRAP USER (NON-LEADER ONLY)
# =========================================================
if [[ "$CURRENT_IP" != "$PRIMARY_IP" ]]; then

    if [[ "$BOOTSTRAP_USER" == "null" || -z "$BOOTSTRAP_USER" ]]; then
        echo "[WARN] No bootstrap user defined, skipping bootstrap setup"
    else
        if id -u "$BOOTSTRAP_USER" >/dev/null 2>&1; then
            echo "[INFO] Bootstrap user already exists"
        else
            echo "[INFO] Creating bootstrap user..."

            useradd -m -s /bin/bash "$BOOTSTRAP_USER"
            echo "$BOOTSTRAP_USER:$BOOTSTRAP_PASS" | chpasswd

            # 🔐 LOCKED DOWN SUDO (ONLY node init)
            echo "$BOOTSTRAP_USER ALL=(ALL) NOPASSWD: /usr/local/bin/swarm-node-init.sh" > "/etc/sudoers.d/$BOOTSTRAP_USER"
            chmod 440 "/etc/sudoers.d/$BOOTSTRAP_USER"

            echo "[INFO] Bootstrap user created with restricted sudo"
        fi
    fi

else
    echo "[INFO] Leader node — skipping bootstrap user creation"
fi

# =========================================================
# HARDEN NODE INIT SCRIPT
# =========================================================
if [[ -f /usr/local/bin/swarm-node-init.sh ]]; then
    chmod 750 /usr/local/bin/swarm-node-init.sh
    chown root:root /usr/local/bin/swarm-node-init.sh
    echo "[INFO] swarm-node-init.sh hardened"
else
    echo "[WARN] swarm-node-init.sh not found (skipping hardening)"
fi

echo "[INFO] swarm-user setup complete"