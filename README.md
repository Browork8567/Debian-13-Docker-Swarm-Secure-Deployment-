# Debian-13-Docker-Swarm-Secure-Deployment

![CI](https://img.shields.io/github/actions/workflow/status/REPLACE_USERNAME/Debian-13-Docker-Swarm-Secure-Deployment/ci.yml?branch=main\&label=CI\&style=flat-square)
![Security](https://img.shields.io/github/actions/workflow/status/REPLACE_USERNAME/Debian-13-Docker-Swarm-Secure-Deployment/security.yml?branch=main\&label=Security\&style=flat-square)
![Last Commit](https://img.shields.io/github/last-commit/REPLACE_USERNAME/Debian-13-Docker-Swarm-Secure-Deployment?style=flat-square)
![Issues](https://img.shields.io/github/issues/REPLACE_USERNAME/Debian-13-Docker-Swarm-Secure-Deployment?style=flat-square)
![License](https://img.shields.io/github/license/REPLACE_USERNAME/Debian-13-Docker-Swarm-Secure-Deployment?style=flat-square)



## Description

Hi! I have been working in my homelab to migrate to Docker Swarm. As I moved through the process, I created multiple scripts with the assistance of AI. However, I have always maintained a security-first posture.

AI is much faster than I will ever be at writing scripts, and if a tool exists, why not use it? I directed the architecture, researched best practices, and used them to shape the infrastructure as I went. I kept AI within a limited scope with clear inputs and expected outputs.

I have tested the scripts, run them myself, and debugged for many hours along the way to reach this point. I thought this was really cool and wanted to share it.

This repo is:
- A production-ready, security-focused Docker Swarm bootstrap for Debian systems.
- Designed for homelabs and small clusters, this project provides automated node provisioning, secure SSH-based swarm   joining, firewall hardening, and optional NAS integration—without relying on shared state or stored tokens.

This is my first time publishing to GitHub, so if the repo is a little rough, I apologize and I am very grateful for any feedback ether on the scripts or how to format the repo in a better way. 🙂


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

* 🔐 Secure Docker install (official repo)
* 🔑 SSH key automation + permissions fix
* 🔥 UFW firewall (Swarm-safe rules)
* 🚫 Fail2Ban (5 attempts → 5-minute ban)
* 🔄 Auto Swarm join (SSH-based, no shared tokens)
* 💾 Optional NAS mount + health guard
* 🧪 CI validation + secret scanning ready
* ♻️ Idempotent design (safe to rerun)

---

## ⚠️ Security Warning

Docker group = root access.
Treat all swarm nodes as **trusted systems**.

---

## 🧱 Architecture

```text
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

## Cli one step deploy, THIS PIPES IN BASH SO BE AWARE IT


curl -fsSL https://raw.githubusercontent.com/yourusername/swarm-secure-bootstrap/main/bootstrap.sh | sudo bash

---

##  Start

### 1. Download the repo

Download ZIP from GitHub and extract.

---

### 2. Configure your environment

Edit:

```bash
config/config.env
```

Update values:

```bash
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

Primary node:

```bash
sudo systemctl start swarm-auto.service
```

Other nodes:

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

```bash
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

#### Option A — Local DNS (Recommended)

```text
mgr-01.lan → 192.168.1.10
mgr-02.lan → 192.168.1.11
mgr-03.lan → 192.168.1.12
```

---

#### Option B — /etc/hosts fallback

Automatically injected:

```bash
192.168.1.10 mgr-01.lan mgr-01
```

---

## 🧩 Post Install

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
* Secrets stored in Docker (not repo)
* Swarm ports restricted to internal network

---

## 🧪 Troubleshooting

### Nodes create their own swarm

```bash
ssh mgr-01.lan
```

Fix DNS or SSH if this fails.

---

### Docker permission denied

```bash
newgrp docker
```

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


```

---

## ❤️ Contributing

Pull requests welcome.
Security improvements especially appreciated.

---

## 📄 License

This project is licensed under the GNU GPLv3 License.
See the LICENSE file for details.



