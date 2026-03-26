#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Running manager sync..."

# Ensure docker is available
if ! docker info >/dev/null 2>&1; then
    echo "[WARN] Docker not available, skipping"
    exit 0
fi

# Only run on leader
if ! docker node ls 2>/dev/null | grep -q Leader; then
    echo "[INFO] Not leader, skipping..."
    exit 0
fi

# Use node IPs (not hostnames)
MANAGERS=$(docker node inspect $(docker node ls --filter role=manager -q) \
    --format '{{ .Status.Addr }}')

WORKERS=$(docker node inspect $(docker node ls --filter role=worker -q) \
    --format '{{ .Status.Addr }}')

MANAGER_COUNT=$(echo "$MANAGERS" | grep -c . || true)

if [[ "$MANAGER_COUNT" -lt 1 ]]; then
    echo "[WARN] No managers detected, skipping sync"
    exit 0
fi

mkdir -p /etc/swarm-bootstrap

MANAGER_JSON=$(printf '%s\n' $MANAGERS | jq -R . | jq -s .)
WORKER_JSON=$(printf '%s\n' $WORKERS | jq -R . | jq -s .)

cat > /etc/swarm-bootstrap/nodes.json <<EOF
{
  "managers": $MANAGER_JSON,
  "workers": $WORKER_JSON
}
EOF

echo "[INFO] nodes.json updated"