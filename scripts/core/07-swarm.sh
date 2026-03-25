#!/bin/bash
set -e

CONFIG="/etc/swarm-bootstrap/config.json"

ROLE=$(jq -r .role "$CONFIG")
MANAGERS=$(jq -r '.managers[]' "$CONFIG")
MODE=$(jq -r .manager_mode "$CONFIG")
PRIORITY=$(jq -r .candidate_priority "$CONFIG")
NODE_IP=$(jq -r .node_ip "$CONFIG")

get_token() {
    TYPE=$1
    for M in $MANAGERS; do
        if sudo -u swarmd ssh -i /home/swarmd/.ssh/id_rsa swarmd@"$M" "docker info" >/dev/null 2>&1; then
            sudo -u swarmd ssh -i /home/swarmd/.ssh/id_rsa swarmd@"$M" "docker swarm join-token -q $TYPE"
            return
        fi
    done
    echo "[ERROR] No reachable managers for token"
    exit 1
}

if [[ "$ROLE" == "manager" ]]; then
    if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
        echo "[INFO] Initializing new swarm..."
        docker swarm init
    else
        echo "[INFO] Already part of a swarm"
    fi
else
    echo "[INFO] Joining swarm as worker..."
    TOKEN=$(get_token worker)

    for M in $MANAGERS; do
        docker swarm join --token "$TOKEN" "$M:2377" && break || true
    done
fi

NODE_ID=$(docker info -f '{{.Swarm.NodeID}}')

# Manager availability
if [[ "$ROLE" == "manager" && "$MODE" != "n/a" ]]; then
    docker node update --availability "$MODE" "$NODE_ID"
fi

# Worker promotion label
if [[ "$ROLE" == "worker" && -n "$PRIORITY" ]]; then
    docker node update --label-add manager_candidate_priority="$PRIORITY" "$NODE_ID"
fi

# ✅ Initialize nodes.json ONLY on first manager
if [[ "$ROLE" == "manager" ]]; then
    mkdir -p /etc/swarm-bootstrap

    if [[ ! -f /etc/swarm-bootstrap/nodes.json ]]; then
        echo "[INFO] Initializing nodes.json"

        cat > /etc/swarm-bootstrap/nodes.json <<EOF
{
  "managers": ["$NODE_IP"],
  "workers": []
}
EOF
    fi
fi

echo "[INFO] Swarm configured"