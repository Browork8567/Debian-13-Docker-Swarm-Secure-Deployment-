#!/bin/bash
set -e

CONFIG="/etc/swarm-bootstrap/config.json"
NODES="/etc/swarm-bootstrap/nodes.json"

echo "[INFO] Syncing swarm node state..."

# Only leader manager updates nodes.json
if [[ "$(docker node inspect self --format '{{.ManagerStatus.Leader}}')" != "true" ]]; then
    echo "[INFO] Not leader, skipping nodes.json update"
    exit 0
fi

mkdir -p /etc/swarm-bootstrap

MANAGERS=()
WORKERS=()

NODE_IDS=$(docker node ls -q)

for ID in $NODE_IDS; do
    ROLE=$(docker node inspect "$ID" -f '{{.Spec.Role}}')
    ADDR=$(docker node inspect "$ID" -f '{{.Status.Addr}}')

    if [[ "$ROLE" == "manager" ]]; then
        MANAGERS+=("\"$ADDR\"")
    else
        WORKERS+=("\"$ADDR\"")
    fi
done

cat > "$NODES" <<EOF
{
  "managers": [$(IFS=,; echo "${MANAGERS[*]}")],
  "workers": [$(IFS=,; echo "${WORKERS[*]}")]
}
EOF

echo "[INFO] nodes.json updated"