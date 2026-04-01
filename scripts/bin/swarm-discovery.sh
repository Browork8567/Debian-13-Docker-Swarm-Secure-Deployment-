#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/swarm-bootstrap/config.json"
LOG_DIR="/var/log/swarm-bootstrap"
DATE=$(date +%F)
LOG_FILE="$LOG_DIR/discovery-$DATE.log"

mkdir -p "$LOG_DIR"

# -------------------------------
# LOAD CONFIG
# -------------------------------
BOOTSTRAP_USER=$(jq -r .bootstrap_user "$CONFIG")
BOOTSTRAP_PASS=$(jq -r .bootstrap_pass "$CONFIG")
PRIMARY_MANAGER=$(jq -r .primary_manager_ip "$CONFIG")
MANAGER_RANGE=$(jq -r '.manager_range[]' "$CONFIG")
WORKER_RANGE=$(jq -r '.worker_range[]' "$CONFIG")

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"

log() {
    echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

log "[INFO] Starting swarm discovery..."

# -------------------------------
# CLEAN OLD LOGS (3 DAY RETENTION)
# -------------------------------
find "$LOG_DIR" -type f -mtime +3 -delete || true

# -------------------------------
# PROCESS NODE FUNCTION
# -------------------------------
process_node() {
    local NODE="$1"

    log "[INFO] Checking node $NODE..."

    # Skip leader
    if [[ "$NODE" == "$PRIMARY_MANAGER" ]]; then
        return
    fi

    # Check if already initialized
    if sshpass -p "$BOOTSTRAP_PASS" ssh $SSH_OPTS "$BOOTSTRAP_USER@$NODE" \
        "test -f /etc/swarm-bootstrap/.node_initialized" >/dev/null 2>&1; then
        log "[INFO] Node $NODE already initialized — skipping"
        return
    fi

    # Test SSH access
    if ! sshpass -p "$BOOTSTRAP_PASS" ssh $SSH_OPTS "$BOOTSTRAP_USER@$NODE" "echo ok" >/dev/null 2>&1; then
        log "[WARN] Node $NODE unreachable or not ready"
        return
    fi

    log "[INFO] Node $NODE reachable — provisioning..."

    # -------------------------------
    # PUSH PUBLIC KEY
    # -------------------------------
    sshpass -p "$BOOTSTRAP_PASS" scp $SSH_OPTS \
        /home/swarmd/.ssh/id_rsa.pub \
        "$BOOTSTRAP_USER@$NODE:/tmp/swarmd.pub"

    # -------------------------------
    # RUN NODE INIT SCRIPT (ROOT)
    # -------------------------------
    sshpass -p "$BOOTSTRAP_PASS" ssh $SSH_OPTS "$BOOTSTRAP_USER@$NODE" \
        "sudo /usr/local/bin/swarm-node-init.sh" \
        >> "$LOG_FILE" 2>&1 || {
            log "[ERROR] Node init failed on $NODE"
            return
        }

    # -------------------------------
    # DETERMINE ROLE
    # -------------------------------
    ROLE="worker"
    for MGR in $MANAGER_RANGE; do
        [[ "$NODE" == "$MGR" ]] && ROLE="manager"
    done

    log "[INFO] Assigning role $ROLE to $NODE"

    # -------------------------------
    # GET TOKEN FROM LEADER
    # -------------------------------
    TOKEN=$(sudo -u swarmd ssh $SSH_OPTS "swarmd@$PRIMARY_MANAGER" \
        "docker swarm join-token -q $ROLE" 2>/dev/null) || {
            log "[ERROR] Failed to get join token"
            return
        }

    # -------------------------------
    # JOIN SWARM
    # -------------------------------
    if sshpass -p "$BOOTSTRAP_PASS" ssh $SSH_OPTS "$BOOTSTRAP_USER@$NODE" \
        "sudo docker swarm join --token $TOKEN $PRIMARY_MANAGER:2377"; then
        log "[SUCCESS] Node $NODE joined swarm as $ROLE"
    else
        log "[ERROR] Swarm join failed for $NODE"
        return
    fi

    # -------------------------------
    # CLEANUP BOOTSTRAP USER (FINAL STEP)
    # -------------------------------
    sshpass -p "$BOOTSTRAP_PASS" ssh $SSH_OPTS "$BOOTSTRAP_USER@$NODE" \
        "sudo userdel -r $BOOTSTRAP_USER || true && sudo rm -f /etc/sudoers.d/$BOOTSTRAP_USER"

    log "[INFO] Bootstrap user removed from $NODE"
}

# -------------------------------
# MAIN LOOP
# -------------------------------
for NODE in $MANAGER_RANGE $WORKER_RANGE; do
    process_node "$NODE"
done

log "[INFO] Swarm discovery complete"