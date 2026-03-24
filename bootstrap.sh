#!/usr/bin/env bash
set -euo pipefail

echo "[BOOTSTRAP] Starting full deployment..."

mkdir -p /opt/swarm-secure
cp config/config.env.example /opt/swarm-secure/config.env || true

for f in scripts/*.sh; do
  chmod +x "$f"
  cp "$f" /usr/local/bin/
done

bash scripts/01-base.sh
sleep 2

bash scripts/02-docker.sh
sleep 3

bash scripts/03-ssh.sh
sleep 2

bash scripts/04-ufw.sh
sleep 2

bash scripts/05-nas.sh
sleep 2

bash scripts/08-hardening.sh

systemctl daemon-reload

echo "[BOOTSTRAP COMPLETE]"
echo ""
echo "NEXT STEPS:"
echo "1. Copy SSH key:"
echo "   ssh-copy-id user@mgr-01"
echo ""
echo "2. Start swarm:"
echo "   systemctl start swarm-auto.service"