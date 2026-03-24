#!/usr/bin/env bash
set -euo pipefail

source /opt/swarm-secure/config.env

echo "[04] Configuring firewall..."

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

ufw allow in on lo

# SSH (restricted)
ufw allow from "$ADMIN_IP" to any port 22 proto tcp

# Swarm ports
ufw allow from "$LAN_SUBNET" to any port 2377 proto tcp
ufw allow from "$LAN_SUBNET" to any port 7946 proto tcp
ufw allow from "$LAN_SUBNET" to any port 7946 proto udp
ufw allow from "$LAN_SUBNET" to any port 4789 proto udp

# Internal trust
ufw allow from "$LAN_SUBNET"
ufw allow from "$VPN_SUBNET"

ufw --force enable

echo "[04] Firewall active."