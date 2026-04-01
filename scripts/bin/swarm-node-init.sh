#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Running controlled node initialization..."

SWARMD_HOME="/home/swarmd"
SSH_DIR="$SWARMD_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
PUB_KEY_FILE="/tmp/swarmd.pub"
HOSTS_FILE="/tmp/swarm-hosts"
JOIN_MARKER="/etc/swarm-bootstrap/.node_initialized"

# -------------------------------
# EARLY EXIT IF ALREADY INITIALIZED
# -------------------------------
if [[ -f "$JOIN_MARKER" ]]; then
    echo "[INFO] Node already initialized — skipping"
    exit 0
fi

# -------------------------------
# ENSURE GROUP (IDEMPOTENT)
# -------------------------------
if getent group swarmd >/dev/null 2>&1; then
    echo "[INFO] swarmd group exists"
else
    groupadd -r swarmd
    echo "[INFO] swarmd group created"
fi

# -------------------------------
# ENSURE USER (IDEMPOTENT)
# -------------------------------
if id -u swarmd >/dev/null 2>&1; then
    echo "[INFO] swarmd user exists"
else
    useradd -r -m -d "$SWARMD_HOME" -s /usr/sbin/nologin -g swarmd swarmd
    echo "[INFO] swarmd user created"
fi

# -------------------------------
# SSH DIRECTORY SETUP
# -------------------------------
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chown -R swarmd:swarmd "$SWARMD_HOME"

# -------------------------------
# AUTHORIZED KEYS (IDEMPOTENT)
# -------------------------------
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"
chown swarmd:swarmd "$AUTHORIZED_KEYS"

if [[ -f "$PUB_KEY_FILE" ]]; then
    PUB_KEY_CONTENT=$(cat "$PUB_KEY_FILE")

    if ! grep -qxF "$PUB_KEY_CONTENT" "$AUTHORIZED_KEYS"; then
        echo "no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-pty $PUB_KEY_CONTENT" >> "$AUTHORIZED_KEYS"
        echo "[INFO] Added swarmd public key"
    else
        echo "[INFO] Public key already present"
    fi

    rm -f "$PUB_KEY_FILE"
else
    echo "[WARN] No public key provided"
fi

# -------------------------------
# HOSTNAME / IP MAPPING
# -------------------------------
if [[ -f "$HOSTS_FILE" ]]; then
    echo "[INFO] Updating /etc/hosts from leader map"

    while read -r line; do
        grep -qxF "$line" /etc/hosts || echo "$line" >> /etc/hosts
    done < "$HOSTS_FILE"

    rm -f "$HOSTS_FILE"
else
    echo "[WARN] No hosts mapping provided"
fi

# -------------------------------
# CREATE JOIN MARKER
# -------------------------------
mkdir -p /etc/swarm-bootstrap
touch "$JOIN_MARKER"
chmod 600 "$JOIN_MARKER"

echo "[INFO] Node marked as initialized"

# -------------------------------
# FINAL PERMISSIONS HARDENING
# -------------------------------
chmod 700 "$SWARMD_HOME"
chown -R swarmd:swarmd "$SWARMD_HOME"

# -------------------------------
# CLEANUP BOOTSTRAP USER (LAST STEP ✅)
# -------------------------------
BOOTSTRAP_USER="bootstrap"

if id -u "$BOOTSTRAP_USER" >/dev/null 2>&1; then
    echo "[INFO] Removing bootstrap user..."
    userdel -r "$BOOTSTRAP_USER" || true
    rm -f "/etc/sudoers.d/$BOOTSTRAP_USER"
    echo "[INFO] Bootstrap user removed"
fi

echo "[INFO] Node initialization complete"