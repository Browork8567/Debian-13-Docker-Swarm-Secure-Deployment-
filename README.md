# Debian-13-Docker-Swarm-Secure-Deployment-
# Secure Docker Swarm Bootstrap

## Features
- Hardened Debian baseline
- Docker Swarm auto-cluster
- SSH key-based auth only
- UFW locked down
- Docker secrets enabled
- NAS optional (secure input)
- Fail2ban protection

## Setup

1. Clone repo
2. Copy config:
   cp config/config.env.example config/config.env
3. Edit values
4. Run:
   sudo bash bootstrap.sh

## Post Install

ssh-copy-id user@mgr-01

sudo systemctl start swarm-auto.service

docker node ls

## Security Model

- No plaintext credentials
- No open LAN firewall
- SSH locked down
- Secrets stored in Docker
- Swarm ports internal only

## WARNING

Docker group = root access.
Treat nodes as trusted.
