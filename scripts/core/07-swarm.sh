#!/bin/bash
set -e

CONFIG="/etc/swarm-bootstrap/config.json"
ROLE=$(jq -r .role "$CONFIG")
NODE_IP=$(jq -r .node_ip "$CONFIG")
MANAGERS=$(jq -r '.managers[]' "$CONFIG")

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

FIRST_MANAGER=$(jq -r '.managers[0]' "$CONFIG")

if [[ "$ROLE" == "manager" ]]; then
    if [[ "$NODE_IP" == "$FIRST_MANAGER" ]]; then
        docker swarm init
    else
        TOKEN=$(get_token manager)
        docker swarm join --token "$TOKEN" "$FIRST_MANAGER:2377"
    fi
else
    echo "[INFO] Joining swarm as worker..."
    TOKEN=$(get_token worker)
    for M in $MANAGERS; do
        docker swarm join --token "$TOKEN" "$M:2377" && break || true
    done
fi

# Initialize nodes.json ONLY on first manager
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