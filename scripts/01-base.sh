#!/usr/bin/env bash
set -euo pipefail

echo "[01] Base system setup..."

apt-get update -qq
apt-get upgrade -y

apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  openssh-server \
  sudo \
  ufw \
  fail2ban

systemctl enable --now ssh

echo "[01] Done."