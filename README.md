# Debian-13-Docker-Swarm-Secure-Deployment

![CI](https://img.shields.io/github/actions/workflow/status/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-/ci.yml?branch=main\&label=CI\&style=flat-square)
![Security](https://img.shields.io/github/actions/workflow/status/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-/security.yml?branch=main\&label=Security\&style=flat-square)
![Last Commit](https://img.shields.io/github/last-commit/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-?style=flat-square)
![Issues](https://img.shields.io/github/issues/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-?style=flat-square)
![License](https://img.shields.io/github/license/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-?style=flat-square)

[![Deploy](https://img.shields.io/badge/Deploy-Homelab-blue?style=for-the-badge)](https://github.com/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-)

---

## 🚀 Overview

A production-ready, security-focused Docker Swarm bootstrap for Debian-based systems.

Designed for homelabs and small clusters, this project provides:

* Automated node provisioning
* Secure SSH-based swarm joining (no token storage)
* Firewall hardening (UFW + Fail2Ban)
* Optional NAS integration
* Idempotent, re-runnable infrastructure

---

## 📦 Features

* Secure Docker install (official repository)
* SSH key automation + permissions fix
* UFW firewall (Swarm-safe rules)
* Fail2Ban (5 attempts → 5-minute ban)
* Auto Swarm join (SSH-based, no shared tokens)
* Optional NAS mount + health guard
* CI validation + secret scanning ready
* Idempotent design (safe to rerun)

---

## ⚠️ Security Warning

Docker group = root access.
Treat all swarm nodes as **trusted systems**.

---

## 🧱 Architecture

```
                    +--------------+
                    |   mgr-01     |
                    |   (Leader)   |
                    |  Drain Mode  |
                    +------+-------+
                           |
            +--------------+--------------+
            |              |              |
     +-------------+ +-------------+ +-------------+
     |   mgr-02    | |   mgr-03    | |  worker-01  |
     | manager+wk  | | manager+wk  | |   worker    |
     +-------------+ +-------------+ +-------------+

        Swarm Ports:
        - 2377 (manager)
        - 7946 (gossip)
        - 4789 (overlay)
```

---


## ⚡ Quick Start

### 1. Download the repo

Download ZIP from GitHub and extract.

---

### 2. Configure your environment

Edit:

```
config/config.env
```

Update values:

```
MGR1_HOSTNAME="mgr-01.lan"
MGR1_IP="192.168.1.10"

LAN_SUBNET="192.168.1.0/24"
ADMIN_IP="192.168.1.50"

NAS_IP="192.168.1.100"
```

---

### 3. Run bootstrap (ALL nodes)

```bash
sudo bash bootstrap.sh
```

---

### 4. Setup SSH trust

Run on all nodes except primary:

```bash
ssh-copy-id <user>@mgr-01.lan
```

---

### 5. Start Swarm

On primary node:

```bash
sudo systemctl start swarm-auto.service
```

On all other nodes:

```bash
sudo systemctl start swarm-auto.service
```

---

### 6. Verify

```bash
docker node ls
```

---

## 🧠 Required Environment Setup

### Hostnames

Each node MUST have a unique hostname:

```
mgr-01
mgr-02
mgr-03
worker-01
```

Set with:

```bash
sudo hostnamectl set-hostname mgr-01
```

---

### DNS (REQUIRED)

You MUST ensure all nodes can resolve the primary manager.

#### Option A — Local DNS (Recommended)

```
mgr-01.lan → 192.168.1.10
mgr-02.lan → 192.168.1.11
mgr-03.lan → 192.168.1.12
```

---

#### Option B — /etc/hosts fallback

The bootstrap automatically injects:

```
192.168.1.10 mgr-01.lan mgr-01
```

---

## 🧩 Post Install

Run on each host:

```bash
ssh-copy-id USER@mgr-01
sudo systemctl start swarm-auto.service
docker node ls
```

---

## 🔐 Security Model

* No plaintext credentials
* No open LAN firewall
* SSH restricted to admin IP
* Fail2Ban enabled (5 attempts → 5-minute ban)
* Secrets stored in Docker (not in repo)
* Swarm ports restricted to internal network only

---

## 🧪 Troubleshooting

### Nodes create their own swarm

```bash
ssh mgr-01.lan
```

If this fails → fix DNS or SSH.

---

### Docker permission denied

```bash
newgrp docker
```

OR log out and back in.

---

### Swarm service fails

```bash
journalctl -xeu swarm-auto.service
```

---

### Stuck joining swarm

```bash
ssh -o BatchMode=yes user@mgr-01.lan docker info
```

---

### SSH permission errors

```bash
sudo chown -R $USER:$USER ~/.ssh
chmod 700 ~/.ssh
chmod 600 ~/.ssh/*
```

---

### NAS issues

```bash
mount | grep /data
sudo /usr/local/bin/docker-mount-guard.sh
```

---

## 🧪 Validation & Safety

This repo includes:

* ShellCheck (linting)
* Gitleaks (secret scanning)
* Dependabot (dependency updates)

---

## 📁 Repository Structure

```
swarm-secure-bootstrap/
│
├── README.md
├── bootstrap.sh
│
├── config/
│   └── config.env.example
│
├── scripts/
│   ├── 01-base.sh
│   ├── 02-docker.sh
│   ├── 03-ssh.sh
│   ├── 04-ufw.sh
│   ├── 05-nas.sh
│   ├── 06-nas-guard.sh
│   ├── 07-swarm.sh
│   ├── 08-hardening.sh
│   └── fail2ban.local
│
├── systemd/
│   ├── docker-mount-guard.service
│   ├── docker-mount-guard.timer
│   └── swarm-auto.service
│
├── portainer/
│   └── stack.yml
│
├── secrets/
│   └── README.md
│
└── .github/
    └── workflows/
        ├── ci.yml
        ├── security.yml
        └── release.yml
```

---

## ❤️ Contributing

Pull requests welcome.
Security improvements especially appreciated.

---

## 📄 License

This project is licensed under the GNU GPLv3 License.
See the LICENSE file for details.
