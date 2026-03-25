#!/usr/bin/env bash
set -euo pipefail

cat << 'EOF' > /usr/local/bin/swarm-role.sh
#!/usr/bin/env bash
set -euo pipefail

HOST=$(hostname)
CURRENT_USER=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")

MGR1_HOSTNAME="${MGR1_HOSTNAME:-mgr-01.lan}"

if docker info 2>/dev/null | grep -q "Swarm: active"; then
    exit 0
fi

#######################################
# PRIMARY MANAGER
#######################################

if [[ "$HOST" == "mgr-01" ]]; then
    echo "[INFO] Initializing primary manager"
    /usr/local/bin/swarm-init.sh

#######################################
# SECONDARY MANAGERS
#######################################

else
    echo "[INFO] Checking if primary manager is reachable..."

    if ssh -o BatchMode=yes -o ConnectTimeout=3 "$CURRENT_USER@$MGR1_HOSTNAME" "docker info" >/dev/null 2>&1; then
        echo "[INFO] Primary reachable → joining"
        /usr/local/bin/swarm-join.sh manager
    else
        echo "[WAIT] Primary not ready yet, retrying..."
        sleep 5
        exit 1
    fi
fi

#######################################
# NODE ROLE BEHAVIOR
#######################################

if docker info | grep -q "Is Manager: true"; then
    if [[ "$HOST" == "mgr-01" ]]; then
        docker node update --availability drain "$HOST" || true
    else
        docker node update --availability active "$HOST" || true
    fi
fi

EOF

chmod +x /usr/local/bin/swarm-role.sh

echo "[07] Swarm ready."