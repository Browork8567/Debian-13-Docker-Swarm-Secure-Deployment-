#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/swarm-bootstrap/config.json"

BOOTSTRAP_USER=$(jq -r .bootstrap_user "$CONFIG")
BOOTSTRAP_PASS=$(jq -r .bootstrap_pass "$CONFIG")
PRIMARY_MANAGER=$(jq -r .primary_manager_ip "$CONFIG")
MANAGER_RANGE=$(jq -r '.manager_range[]' "$CONFIG")
WORKER_RANGE=$(jq -r '.worker_range[]' "$CONFIG")

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"

echo "[INFO] Starting swarm discovery..."

for NODE in $MANAGER_RANGE $WORKER_RANGE; do
    echo "[INFO] Checking node $NODE..."

    # Skip self
    if [[ "$NODE" == "$PRIMARY_MANAGER" ]]; then
        continue
    fi

    # Test bootstrap SSH access
    if ! sshpass -p "$BOOTSTRAP_PASS" ssh $SSH_OPTS "$BOOTSTRAP_USER@$NODE" "echo ok" >/dev/null 2>&1; then
        echo "[INFO] Node $NODE not ready or unreachable"
        continue
    fi

    echo "[INFO] Node $NODE reachable. Provisioning..."

    # -------------------------------
    # CREATE swarmd USER + GROUP (IDEMPOTENT)
    # -------------------------------
    sshpass -p "$BOOTSTRAP_PASS" ssh $SSH_OPTS "$BOOTSTRAP_USER@$NODE" bash -s <<'EOF'
set -e

# Create group if missing
if getent group swarmd >/dev/null; then
    echo "[INFO] swarmd group exists"
else
    groupadd swarmd
    echo "[INFO] swarmd group created"
fi

# Create user if missing
if id -u swarmd >/dev/null 2>&1; then
    echo "[INFO] swarmd user exists"
else
    useradd -r -m -d /home/swarmd -s /usr/sbin/nologin -g swarmd swarmd
    echo "[INFO] swarmd user created"
fi

# Ensure docker group membership
if getent group docker >/dev/null; then
    usermod -aG docker swarmd || true
fi

# Ensure SSH directory
mkdir -p /home/swarmd/.ssh
chown -R swarmd:swarmd /home/swarmd
chmod 700 /home/swarmd/.ssh
EOF

    # -------------------------------
    # PUSH SSH KEY (IDEMPOTENT)
    # -------------------------------
    PUB_KEY=$(cat /home/swarmd/.ssh/id_rsa.pub)

    sshpass -p "$BOOTSTRAP_PASS" ssh $SSH_OPTS "$BOOTSTRAP_USER@$NODE" \
        "grep -qxF '$PUB_KEY' /home/swarmd/.ssh/authorized_keys 2>/dev/null || \
         echo '$PUB_KEY' >> /home/swarmd/.ssh/authorized_keys && \
         chown swarmd:swarmd /home/swarmd/.ssh/authorized_keys && \
         chmod 600 /home/swarmd/.ssh/authorized_keys"

    # -------------------------------
    # DETERMINE ROLE BY IP RANGE
    # -------------------------------
    ROLE="worker"
    for MGR in $MANAGER_RANGE; do
        if [[ "$NODE" == "$MGR" ]]; then
            ROLE="manager"
        fi
    done

    echo "[INFO] Assigning role $ROLE to $NODE"

    # -------------------------------
    # JOIN SWARM
    # -------------------------------
    TOKEN=$(sudo -u swarmd ssh $SSH_OPTS "swarmd@$PRIMARY_MANAGER" \
        "docker swarm join-token -q $ROLE")

    sshpass -p "$BOOTSTRAP_PASS" ssh $SSH_OPTS "$BOOTSTRAP_USER@$NODE" \
        "docker swarm join --token $TOKEN $PRIMARY_MANAGER:2377" || true

    # -------------------------------
    # CLEANUP BOOTSTRAP USER
    # -------------------------------
    sshpass -p "$BOOTSTRAP_PASS" ssh $SSH_OPTS "$BOOTSTRAP_USER@$NODE" \
        "userdel -r $BOOTSTRAP_USER || true"

    echo "[INFO] Node $NODE processed"
done

echo "[INFO] Swarm discovery complete"