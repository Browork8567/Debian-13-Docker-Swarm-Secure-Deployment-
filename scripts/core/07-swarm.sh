#!/bin/bash
set -e

echo "[INFO] Configuring Docker Swarm..."

# Wait for Docker
until docker info >/dev/null 2>&1; do
    echo "[INFO] Waiting for Docker..."
    sleep 2
done

ROLE=$(jq -r .role /etc/swarm-bootstrap/config.json)
NODE_IP=$(jq -r .node_ip /etc/swarm-bootstrap/config.json)

if [[ "$ROLE" == "manager" ]]; then

    if ! docker info | grep -q "Swarm: active"; then
        echo "[INFO] Initializing swarm..."
        docker swarm init --advertise-addr "$NODE_IP"

        mkdir -p /etc/swarm-bootstrap
        cat > /etc/swarm-bootstrap/nodes.json <<EOF
{
  "managers": ["$NODE_IP"],
  "workers": []
}
EOF
    fi

else
    echo "[INFO] Joining swarm as worker..."

    for i in {1..5}; do
        TOKEN=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no manager "docker swarm join-token -q worker") && break
        sleep 3
    done

    docker swarm join --token "$TOKEN" manager:2377 || echo "[WARN] Join failed after retries"
fi

echo "[INFO] Swarm configuration complete."