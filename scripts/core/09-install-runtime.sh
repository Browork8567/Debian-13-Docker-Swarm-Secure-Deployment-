#!/bin/bash
set -e


install -m 0755 scripts/bin/swarm-health.sh /usr/local/bin/swarm-health.sh
install -m 0755 scripts/bin/swarm-manager-sync.sh /usr/local/bin/swarm-manager-sync.sh

echo "[INFO] Installing systemd units..."

cp systemd/*.service /etc/systemd/system/
cp systemd/*.timer /etc/systemd/system/

systemctl daemon-reload

systemctl enable swarm-health.timer
systemctl enable swarm-manager-sync.timer

systemctl enable docker-mount-guard.timer
systemctl start docker-mount-guard.timer

systemctl start swarm-health.timer
systemctl start swarm-manager-sync.timer

echo "[INFO] Runtime installation complete"