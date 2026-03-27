#!/bin/bash
set -euo pipefail

echo "[INFO] Creating swarmd service account..."

# -------------------------------
# CREATE USER (idempotent)
# -------------------------------
if id -u swarmd >/dev/null 2>&1; then
    echo "[INFO] swarmd user already exists"
else
    useradd -r -m -d /home/swarmd -s /usr/sbin/nologin swarmd
    echo "[INFO] swarmd user created"
fi

# Check if group exists; create if missing
if getent group swarmd >/dev/null 2>&1; then
    echo "[INFO] swarmd group already exists"
else
    echo "[INFO] Creating swarmd group..."
    groupadd -r swarmd
    echo "[INFO] swarmd group created"
fi


# -------------------------------
# ENSURE HOME + SSH DIR
# -------------------------------
HOME_DIR="/home/swarmd"
SSH_DIR="$HOME_DIR/.ssh"

mkdir -p "$SSH_DIR"

chown -R swarmd:swarmd "$HOME_DIR"
chmod 700 "$SSH_DIR"

# -------------------------------
# SSH KEY GENERATION (if missing)
# -------------------------------
if [[ ! -f "$SSH_DIR/id_rsa" ]]; then
    echo "[INFO] Generating SSH key for swarmd..."
    sudo -u swarmd ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/id_rsa" -N ""
else
    echo "[INFO] SSH key already exists"
fi

chmod 600 "$SSH_DIR/id_rsa"
chmod 644 "$SSH_DIR/id_rsa.pub"

# -------------------------------
# AUTHORIZED KEYS FILE
# -------------------------------
touch "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/authorized_keys"
chown swarmd:swarmd "$SSH_DIR/authorized_keys"

# -------------------------------
# ADD TO DOCKER GROUP
# -------------------------------
if getent group docker >/dev/null; then
    usermod -aG docker swarmd
    echo "[INFO] swarmd added to docker group"
else
    echo "[WARN] docker group not found (Docker not installed yet?)"
fi

# -------------------------------
# VALIDATION
# -------------------------------
echo "[INFO] Validating swarmd docker access..."

if sudo -u swarmd docker info >/dev/null 2>&1; then
    echo "[INFO] swarmd can access docker"
else
    echo "[WARN] swarmd cannot access docker yet (will work after re-login/systemd)"
fi

echo "[INFO] swarmd account ready"

# -------------------------------
# Boostrap temp user
# -------------------------------


BOOTSTRAP_USER=$(jq -r .bootstrap_user /etc/swarm-bootstrap/config.json)
BOOTSTRAP_PASS=$(jq -r .bootstrap_password /etc/swarm-bootstrap/config.json)

if id -u "$BOOTSTRAP_USER" >/dev/null 2>&1; then
    echo "[INFO] Bootstrap user exists"
else
    useradd -m -s /bin/bash "$BOOTSTRAP_USER"
    echo "$BOOTSTRAP_USER:$BOOTSTRAP_PASS" | chpasswd
    usermod -aG sudo "$BOOTSTRAP_USER"

    echo "$BOOTSTRAP_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$BOOTSTRAP_USER"
    chmod 440 "/etc/sudoers.d/$BOOTSTRAP_USER"

    echo "[INFO] Bootstrap user created"
fi