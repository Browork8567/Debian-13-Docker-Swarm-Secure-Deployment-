#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/swarm-bootstrap/config.json"
CRED_FILE="/root/.nas-cred"

if [[ ! -f "$CONFIG" ]]; then
    echo "[WARN] Config file not found, skipping NAS setup"
    exit 0
fi

echo "[06] Mounting NAS (optional)..."

# Load config
NAS_IP=$(jq -r .nas_ip "$CONFIG")
NAS_SHARE_NAME=$(jq -r .nas_share "$CONFIG")
NAS_PATH=$(jq -r .nas_path "$CONFIG")
NAS_UID=$(jq -r .nas_uid "$CONFIG")
NAS_GID=$(jq -r .nas_gid "$CONFIG")

# Skip if NAS not configured
if [[ "$NAS_IP" == "null" || -z "$NAS_IP" ]]; then
    echo "[INFO] NAS not configured, skipping..."
    exit 0
fi

# Validate required fields
if [[ "$NAS_SHARE_NAME" == "null" || -z "$NAS_SHARE_NAME" ]]; then
    echo "[WARN] NAS share missing, skipping"
    exit 0
fi

if [[ "$NAS_PATH" == "null" || -z "$NAS_PATH" ]]; then
    echo "[WARN] NAS path missing, skipping"
    exit 0
fi

# Validate credentials file
if [[ ! -f "$CRED_FILE" ]]; then
    echo "[WARN] Credentials file not found, skipping mount"
    exit 0
fi

# Safe defaults for UID/GID
NAS_UID=${NAS_UID:-1000}
NAS_GID=${NAS_GID:-1000}

# Build share path (IP-based, no DNS dependency)
NAS_SHARE="//${NAS_IP}/${NAS_SHARE_NAME}"

# Ensure mount point exists (extra safety even though config creates it)
mkdir -p "$NAS_PATH"

# Mount options (resilient + container-friendly)
MOUNT_OPTS="credentials=${CRED_FILE},_netdev,iocharset=utf8,uid=${NAS_UID},gid=${NAS_GID},nofail,x-systemd.automount,x-systemd.device-timeout=10"

FSTAB_ENTRY="${NAS_SHARE} ${NAS_PATH} cifs ${MOUNT_OPTS} 0 0"

# Add to fstab if not already present
if ! grep -q "$NAS_SHARE" /etc/fstab; then
    echo "[INFO] Adding NAS mount to /etc/fstab"
    echo "$FSTAB_ENTRY" >> /etc/fstab
else
    echo "[INFO] NAS already present in /etc/fstab"
fi

# Attempt mount (non-blocking)
if mount -a; then
    echo "[INFO] NAS mounted successfully"
else
    echo "[WARN] NAS mount failed (continuing)"
fi

echo "[06] NAS step complete (non-blocking)."