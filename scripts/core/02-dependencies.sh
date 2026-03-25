#!/bin/bash
set -e

echo "[INFO] Installing dependencies (Docker + jq)..."

# Base packages required
apt-get update
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    jq

# Docker repo setup
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update

# Install ONLY required Docker components
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io

# Enable Docker
systemctl enable docker
systemctl start docker

echo "[INFO] Dependencies installed successfully"

echo "[INFO] Docker installed successfully"