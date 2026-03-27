#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Running manager sync..."

# Only leader executes
if ! docker node ls 2>/dev/null | grep -q Leader; then
    echo "[INFO] Not leader, skipping..."
    exit 0
fi

# Gather nodes
MANAGERS=$(docker node ls --format '{{.Hostname}} {{.ManagerStatus}}' | \
    awk '$2 ~ /Leader|Reachable/ {print $1}')

WORKERS=$(docker node ls --format '{{.Hostname}} {{.ManagerStatus}}' | \
    awk '$2 == "" {print $1}')

MANAGER_COUNT=$(echo "$MANAGERS" | grep -c . || true)

# -------------------------------
# MANAGER SYNC GUARD (FIX 6)
# -------------------------------
if [[ "$MANAGER_COUNT" -lt 1 ]]; then
    echo "[WARN] No managers detected, skipping sync"
    exit 0
fi

mkdir -p /etc/swarm-bootstrap

# Build JSON safely
MANAGER_JSON=$(printf '%s\n' $MANAGERS | jq -R . | jq -s .)
WORKER_JSON=$(printf '%s\n' $WORKERS | jq -R . | jq -s .)

cat > /etc/swarm-bootstrap/nodes.json <<EOF
{
  "managers": $MANAGER_JSON,
  "workers": $WORKER_JSON
}
EOF

# Validate JSON
if ! jq empty /etc/swarm-bootstrap/nodes.json >/dev/null 2>&1; then
    echo "[ERROR] nodes.json invalid!"
    exit 1
fi

echo "[INFO] nodes.json updated successfully"