#!/usr/bin/env bash
set -euo pipefail

echo "[02] Installing Docker..."

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

ARCH="$(dpkg --print-architecture)"
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"

echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $CODENAME stable" \
> /etc/apt/sources.list.d/docker.list

apt-get update -qq

apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker

CURRENT_USER=$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")
usermod -aG docker "$CURRENT_USER"

echo "[02] Docker installed. Run 'newgrp docker' or relog."