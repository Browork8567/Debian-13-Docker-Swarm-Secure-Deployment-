#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/swarm-bootstrap/config.json"
NODES="/etc/swarm-bootstrap/nodes.json"
LOCK_FILE="/var/run/swarm-recovery.lock"

exec 200>$LOCK_FILE
flock -n 200 || exit 0

[[ ! -f "$CONFIG" ]] && exit 0
[[ ! -f "$NODES" ]] && exit 0

ROLE=$(jq -r .role "$CONFIG")

# -------------------------------
# REJOIN LOGIC
# -------------------------------
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo "[WARN] Node not in swarm, attempting rejoin..."

    for MANAGER in $(jq -r '.managers[]' "$NODES"); do
        if ssh -o ConnectTimeout=3 "$MANAGER" "docker info" >/dev/null 2>&1; then
            TOKEN=$(ssh "$MANAGER" "docker swarm join-token -q $ROLE")
            docker swarm join --token "$TOKEN" "$MANAGER:2377" && break
        fi
        done
fi

# Only managers handle quorum
if [[ "$ROLE" != "manager" ]]; then
    exit 0
fi

[[ ! -f /etc/swarm-bootstrap/.initialized ]] && exit 0

TOTAL=$(docker node ls --filter role=manager -q | wc -l)
REACHABLE=$(docker node ls --format '{{.ManagerStatus}}' | grep -c Reachable || true)
QUORUM=$((TOTAL / 2 + 1))

if [[ "$REACHABLE" -lt "$QUORUM" ]]; then
    echo "[CRITICAL] Quorum at risk, promoting candidate..."

    CANDIDATE=$(docker node ls --filter role=worker --format '{{.ID}}' | while read -r ID; do
        PRIORITY=$(docker node inspect "$ID" \
            --format '{{ index .Spec.Labels "manager_candidate_priority" }}' 2>/dev/null || true)

        if [[ -n "$PRIORITY" ]]; then
            echo "$PRIORITY $ID"
        fi
    done | sort -n | head -1)

    if [[ -n "$CANDIDATE" ]]; then
        PRIORITY=$(echo "$CANDIDATE" | awk '{print $1}')
        NODE_ID=$(echo "$CANDIDATE" | awk '{print $2}')

        STATE=$(docker node inspect "$NODE_ID" --format '{{.Status.State}}')

        if [[ "$STATE" == "ready" ]]; then
            docker node promote "$NODE_ID"
            echo "[INFO] Promoted node $NODE_ID"
        else
            echo "[WARN] Candidate not ready, skipping promotion"
        fi
    else
        echo "[WARN] No eligible promotion candidates found"
    fi
fi