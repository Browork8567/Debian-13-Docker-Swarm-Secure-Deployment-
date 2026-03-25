#!/bin/bash
set -e

LOG_FILE="/var/log/swarm-bootstrap.log"

# Ensure root

if [[ $EUID -ne 0 ]]; then
echo "[ERROR] Please run as root"
exit 1
fi

# Setup logging

mkdir -p /var/log
touch "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "======================================"
echo "[INFO] Swarm Bootstrap Started: $(date)"
echo "======================================"

# Error trap

trap 'echo "[ERROR] Script failed at line $LINENO"' ERR

# Ensure jq is installed early

echo "[INFO] Installing dependencies..."
apt-get update
apt-get install -y jq

# Script execution helper

run_script() {
SCRIPT=$1
echo "--------------------------------------"
echo "[INFO] Running $SCRIPT"
echo "--------------------------------------"

bash "$SCRIPT"

echo "[INFO] Completed $SCRIPT"
}

# Execute scripts in order

run_script scripts/core/01-config.sh
run_script scripts/core/02-base.sh
run_script scripts/core/03-docker.sh
run_script scripts/core/04-swarm-user.sh
run_script scripts/core/05-ssh.sh
run_script scripts/core/06-ufw.sh
run_script scripts/core/07-nas.sh
run_script scripts/core/08-swarm.sh
run_script scripts/core/09-hardening.sh
run_script scripts/core/10-runtime.sh

echo "======================================"
echo "[INFO] Bootstrap Completed Successfully"
echo "Log file: $LOG_FILE"
echo "======================================"
