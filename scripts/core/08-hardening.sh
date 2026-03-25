#!/usr/bin/env bash
set -euo pipefail

echo "[08] Applying system hardening..."

#######################################
# FAIL2BAN CONFIG (5 attempts / 5 min)
#######################################

cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 5m
findtime = 5m
maxretry = 5

[sshd]
enabled = true
EOF

systemctl enable --now fail2ban

#######################################
# SSH HARDENING
#######################################

sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

systemctl restart ssh

echo "[08] Hardening complete."