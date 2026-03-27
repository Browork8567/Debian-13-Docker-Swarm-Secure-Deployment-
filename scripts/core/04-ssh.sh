#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Preparing SSH environment for swarmd (local only)..."

HOME_DIR="/home/swarmd"
SSH_DIR="$HOME_DIR/.ssh"
KEY_FILE="$SSH_DIR/id_rsa"

# -------------------------------
# ENSURE DIRECTORY
# -------------------------------
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chown swarmd:swarmd "$SSH_DIR"

# -------------------------------
# KEY GENERATION (IDEMPOTENT)
# -------------------------------
if [[ ! -f "$KEY_FILE" ]]; then
    echo "[INFO] Generating SSH key for swarmd..."
    sudo -u swarmd ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N ""
else
    echo "[INFO] SSH key already exists"
fi

chmod 600 "$KEY_FILE"
chmod 644 "$KEY_FILE.pub"
chown swarmd:swarmd "$KEY_FILE" "$KEY_FILE.pub"

# -------------------------------
# AUTHORIZED_KEYS (LOCAL ONLY)
# -------------------------------
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"
chown swarmd:swarmd "$AUTHORIZED_KEYS"

echo "[INFO] SSH prepared (distribution handled by leader discovery)"