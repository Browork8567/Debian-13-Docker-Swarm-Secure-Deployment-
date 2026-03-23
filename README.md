# Debian-13-Docker-Swarm-Secure-Deployment-

Description

Hi! I have been working in my homelab to migrate to docker swarm. As I moved through the process i had multiple scripts written by AI but I have always kept a security first posture in mind. AI  is much faster than i ever will be at writing them, and if a tool exists why not use it?  I directed the architecture, and researched best practices and used them to shape the infastructure as i went. I kept AI to a  limited scope with clear inputs and expected outputs. I double checked function the scripts, have run them myself, and have debugged for many hours along the way to get to this point. I thought this was really cool and wanted to share. 

This is my first time publishing to github so if the repo is a little weird, I appologize and I am eternally greatful for any help. :) 

# Deployment Philosophy

* **Idempotent** → safe to re-run
* **No shared state dependency** (no NAS tokens)
* **Self-healing where possible**
* **Fail-safe where not**

---


## ⚠️ WARNING

Scripts were written with the assitance of AI

Docker group = root access.
Treat all swarm nodes as **trusted systems**.

---

# 🚀 Swarm Secure Bootstrap

Production-ready Docker Swarm bootstrap for Debian-based systems.

---

## ✨ Features

* Secure Docker installation (official repo)
* SSH key automation + hardening
* UFW firewall (Swarm-safe)
* Fail2Ban (5 attempts → 5 minute ban)
* Auto Swarm join (SSH-based, no tokens stored)
* Optional NAS integration (non-blocking)
* No plaintext credentials in repo
* CI validation + secret scanning ready

---
## 🔐 Security Model

* No plaintext credentials
* No open LAN firewall
* SSH locked to admin IP
* Fail2Ban enabled (5 attempts → 5 min ban)
* Secrets should be stored in Docker (not repo)
* Swarm ports restricted to internal network only

---

# ⚡ Quick Start

## 1. Clone or download repo

(Download ZIP from GitHub UI and extract)

## 2. Edit configuration

Edit:

```
- config/config.env

```

Update:


MGR1_HOSTNAME="mgr-01.lan"
MGR1_IP="192.168.1.10"

LAN_SUBNET="192.168.1.0/24"
ADMIN_IP="192.168.1.50"

NAS_IP="192.168.1.100"

```

## 3. Run bootstrap on EACH node


- sudo bash bootstrap.sh

```

---

## 4. Setup SSH trust (REQUIRED)

Run on all nodes except primary:


ssh-copy-id <user>@mgr-01.lan
```

---

## 5. Start swarm

On primary manager:

```bash
sudo systemctl start swarm-auto.service
```

Then on all other nodes:

sudo systemctl start swarm-auto.service

```

---

## 6. Verify cluster

docker node ls

```

# 🧠 Required Environment Setup

## Hostnames

Each node MUST have a unique hostname:

```
mgr-01
mgr-02
mgr-03
worker-01

```

Set with:

sudo hostnamectl set-hostname mgr-01

```

## DNS (REQUIRED)

You MUST ensure all nodes can resolve the primary manager.

### Option A — Local DNS (recommended)

Example using Pi-hole:

```
mgr-01.lan → 192.168.1.10
mgr-02.lan → 192.168.1.11
mgr-03.lan → 192.168.1.12
```

---

### Option B — /etc/hosts fallback

The bootstrap automatically injects:

```
192.168.1.10 mgr-01.lan mgr-01
```
## 🧩 Post Install (Minimal)

- on each host
ssh-copy-id USER@mgr-01
sudo systemctl start swarm-auto.service
docker node ls

# 🧱 Architecture

```
                ┌──────────────┐
                │  mgr-01      │
                │  (Leader)    │
                │  Drain Mode  │
                └──────┬───────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
 ┌────────────┐ ┌────────────┐ ┌────────────┐
 │ mgr-02     │ │ mgr-03     │ │ worker-01  │
 │ manager+wk │ │ manager+wk │ │ worker     │
 └────────────┘ └────────────┘ └────────────┘

        Swarm Ports:
        2377 (manager)
        7946 (gossip)
        4789 (overlay)
```

---

# 🧪 Troubleshooting

## ❌ Nodes create their own swarm

**Cause:**

* Cannot reach mgr-01
* DNS failure
* SSH failure

**Fix:**

```bash
ssh mgr-01.lan
```

If this fails → fix DNS or SSH.

---

## ❌ `permission denied docker.sock`

```bash
newgrp docker
```

OR log out and back in.

---

## ❌ Swarm port 2377 disappears

**Cause:**
Docker daemon restart (NOT a swarm failure)

Check:

```bash
journalctl -u docker -f
```

If you see:

```
Stopping Docker Application Container Engine
```

→ something is restarting Docker (fix that, not swarm)

---

## ❌ swarm-auto.service fails

```bash
journalctl -xeu swarm-auto.service
```

Common causes:

* SSH not set up
* mgr-01 unreachable
* wrong hostname
* DNS failure

---

## ❌ Stuck on “Waiting for mgr-01”

Check:

```bash
ssh -o BatchMode=yes user@mgr-01.lan docker info
```

If this fails → fix SSH or Docker permissions on mgr-01

---

## ❌ Permission denied writing to ~/.ssh

Fix ownership:

```bash
sudo chown -R $USER:$USER ~/.ssh
chmod 700 ~/.ssh
chmod 600 ~/.ssh/*
```

---

## ❌ NAS mount issues

Check:

```bash
mount | grep /data
```

Run guard manually:

```bash
sudo /usr/local/bin/docker-mount-guard.sh
```


## 🧪 Validation & Safety

This repo includes:

* Shell script linting (ShellCheck)
* Secret scanning (Gitleaks)
* Dependency monitoring (Dependabot)



