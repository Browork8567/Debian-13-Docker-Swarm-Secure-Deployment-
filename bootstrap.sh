#!/bin/bash
set -e

LOG_FILE="/var/log/swarm-bootstrap.log"

# Ensure root
if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Please run as root"
  exit 1
fi

mkdir -p /var/log
touch "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "======================================"
echo "[INFO] Swarm Bootstrap Started: $(date)"
echo "======================================"

trap 'echo "[ERROR] Script failed at line $LINENO"' ERR

# Log node and role for context
NODE=$(hostname)
ROLE=$(jq -r .role /etc/swarm-bootstrap/config.json 2>/dev/null || echo "unknown")
echo "[INFO] Node: $NODE"
echo "[INFO] Role: $ROLE"

run_script() {
  SCRIPT=$1
  echo "--------------------------------------"
  echo "[INFO] Running $SCRIPT"
  echo "--------------------------------------"

  bash "$SCRIPT"

  echo "[INFO] Completed $SCRIPT"
}

run_script scripts/core/01-config.sh

# Validate config
jq empty /etc/swarm-bootstrap/config.json || {
  echo "[ERROR] Invalid config.json"
  exit 1
}

run_script scripts/core/02-dependencies.sh
run_script scripts/core/03-base.sh
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