#!/bin/bash
set -e

echo "[INFO] Installing dependencies..."

apt-get update

# Install base tools
apt-get install -y ca-certificates curl gnupg lsb-release

# Install openssh-client if missing
if ! command -v ssh >/dev/null 2>&1; then
    apt-get install -y openssh-client
fi

# Install Docker only if not present
if ! command -v docker >/dev/null 2>&1; then
    echo "[INFO] Installing Docker..."

    install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/debian/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io

    systemctl enable docker
    systemctl start docker
else
    echo "[INFO] Docker already installed"
fi

echo "[INFO] Dependencies installed."
