# Docker-Swarm-Bootstrap-for-Debian


![Security](https://img.shields.io/github/actions/workflow/status/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-/security.yml?branch=main\&label=Security\&style=flat-square)
![Last Commit](https://img.shields.io/github/last-commit/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-?style=flat-square)
![Issues](https://img.shields.io/github/issues/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-?style=flat-square)
![License](https://img.shields.io/github/license/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-?style=flat-square)

[![Deploy](https://img.shields.io/badge/Deploy-Homelab-blue?style=for-the-badge)](https://github.com/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-)

---

---

# Docker Swarm Bootstrap for Debian

Automated bootstrap scripts for setting up **Docker Swarm clusters** on fresh Debian installs, including multi-manager support, worker nodes, health checks, and automated recovery.

This repo allows you to go from a bare Debian VM to a fully operational Docker Swarm cluster with *interactive setup***, modular scripts, and secure defaults.

---

## Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Requirements](#requirements)
4. [Architecture](#architecture)
5. [Script Workflow](#script-workflow)
6. [Interactive Configuration](#interactive-configuration)
7. [Node Registry & UFW Sync](#node-registry--ufw-sync)
8. [Manager Candidate Labels & Promotion Policy](#manager-candidate-labels--promotion-policy)
9. [Health Checks & Auto-Recovery](#health-checks--auto-recovery)
10. [Security Model](#security-model)
11. [Installation / Bootstrap](#installation--bootstrap)
12. [Post-Bootstrap Verification](#post-bootstrap-verification)
13. [Troubleshooting](#troubleshooting)
14. [Optional Improvements](#optional-improvements)

---

## Overview

This repository provides a modular set of scripts to:

* Install Docker on Debian
* Configure SSH and system users
* Initialize or join Docker Swarm (multi-manager capable)
* Setup UFW firewall rules
* Enable runtime health checks and auto-recovery
* Maintain a dynamic node registry (`nodes.json`)
* Handle NAS integration (optional)
* Provide modular logging and auditability

---

## Features

* Interactive configuration for node roles, IPs, admin user, and NAS credentials
* Automatic leader election among managers
* Candidate labels for safe manager promotion
* Health-check-driven node recovery
* Systemd timers for UFW, health checks, and node sync
* Secure `swarmd` service account with restricted SSH
* Dynamic `nodes.json` registry updated by swarm leader
* Logging of all bootstrap activities for traceability

---

## Requirements

* Debian 12+ (fresh VM recommended)
* Root access for bootstrap execution
* Network connectivity between all managers and workers
* Admin user access for initial SSH setup

**Recommended network:**

* Dedicated Swarm subnet optional but recommended
* SSH access must be allowed for the `swarmd` service account

---

## Architecture

```text
+----------------------------+
|      Bootstrap Script      |
+----------------------------+
          |
          v
+----------------------------+
|  Interactive Config (01)   |
+----------------------------+
          |
          v
+----------------------------+
| Dependencies (02)          |
| Docker + jq + openssh      |
+----------------------------+
          |
          v
+----------------------------+
| Swarmd Account (04)        |
| No-login shell, docker grp |
+----------------------------+
          |
          v
+----------------------------+
| SSH Trust (05)             |
| Restricted keys            |
+----------------------------+
          |
          v
+----------------------------+
| UFW Firewall (06)          |
+----------------------------+
          |
          v
+----------------------------+
| Optional NAS (07)          |
+----------------------------+
          |
          v
+----------------------------+
| Swarm Init / Join (08)     |
| First manager logic        |
| Workers auto join          |
+----------------------------+
          |
          v
+----------------------------+
| Hardening (09)             |
| Fail2Ban + sysctl tweaks   |
+----------------------------+
          |
          v
+----------------------------+
| Runtime Services (10)      |
| - Health-check timer       |
| - Manager-sync timer       |
| - UFW-sync timer           |
| - NAS guard                |
+----------------------------+
```

---

## Script Workflow

| Step | Script               | Description                                                                                                    |
| ---- | -------------------- | -------------------------------------------------------------------------------------------------------------- |
| 1    | `01-config.sh`       | Interactive collection of node role, IPs, admin user, admin IP, NAS info, candidate labels                     |
| 2    | `02-dependencies.sh` | Installs Docker, `jq`, `openssh-client`, containerd, and base system prep (merged from previous `base` script) |
| 3    | `04-swarm-user.sh`   | Creates `swarmd` user, sets permissions, no-login shell                                                        |
| 4    | `05-ssh.sh`          | Configures SSH keys for `swarmd`, ensures `.ssh` directory exists on remote nodes, restricted access           |
| 5    | `06-ufw.sh`          | Initializes firewall rules for admin + Swarm ports                                                             |
| 6    | `07-nas.sh`          | Optional NAS setup (integrated with health guards at runtime)                                                  |
| 7    | `08-swarm.sh`        | Initializes Swarm (first manager only), joins workers, sets `nodes.json`                                       |
| 8    | `09-hardening.sh`    | Security hardening (Fail2Ban, sysctl, Docker daemon tweaks)                                                    |
| 9    | `10-runtime.sh`      | Enables systemd timers for health checks, UFW sync, manager-sync, NAS guard                                    |

> Each step logs to `/var/log/swarm-bootstrap.log` with timestamps and node role context.

---

## Interactive Configuration

* Collects **all variables up front**
* Avoids storing plain text passwords
* Prompts include:

  * Node role (`manager` / `worker`)
  * Node IP / Hostname
  * Admin user & admin IP (with override)
  * Candidate label for worker promotion
  * NAS credentials (stored encrypted locally)
* Ensures future scripts can run **non-interactively**

---

## Node Registry & UFW Sync

* `nodes.json` stored at `/etc/swarm-bootstrap/nodes.json`
* Leader-only manager updates this file automatically
* Syncs with systemd timer every **5 minutes**
* Ensures firewall rules reflect current swarm nodes
* Workers are listed explicitly, manager IPs only allow inbound SSH from other managers and admin IP
* Avoids worker nodes opening unnecessary inbound ports

**Sample `nodes.json`**

```json
{
  "managers": ["10.0.0.1", "10.0.0.2", "10.0.0.3"],
  "workers": ["10.0.0.4", "10.0.0.5", "10.0.0.6", "10.0.0.7", "10.0.0.8"]
}
```

---

## Manager Candidate Labels & Promotion Policy

* Workers can be assigned a **candidate label** (e.g., `manager-candidate01`)
* Only **one node is promoted at a time** if quorum is at risk
* Prevents race conditions during auto-promotion
* Candidate labels must be **unique per node**
* Swarm checks candidate order for safe promotion

---

## Health Checks & Auto-Recovery

* Systemd service `swarm-health.service` monitors nodes
* Detects failed nodes and automatically re-joins them to the cluster
* Works in tandem with `swarm-manager-sync.timer` and `swarm-ufw-sync.timer`
* NAS health guard integrated in runtime
* Helps maintain cluster stability even if one manager fails

---

## Security Model

* `swarmd` service account:

  * No-login shell
  * Only handles Docker and SSH automation
  * Added to `docker` and `ssh` groups
  * SSH keys restricted (`no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-pty`)
  * Only admin IP allowed inbound
* Admin user retains full SSH access
* Workers:

  * Outbound SSH allowed for joining / retrieving tokens
  * Inbound SSH only allowed for admin (optional)
* Systemd timers run as root or swarmd as needed, following **least privilege** principle

> **Warning:** Swarmd is a privileged automation account — treat SSH keys as sensitive.

---

## Installation / Bootstrap

1. Pull the bootstrap script on each node:

```bash
curl -fsSL https://raw.githubusercontent.com/Browork8567/Docker-Swarm-Bootstrap-Debian/main/bootstrap.sh -o bootstrap.sh
chmod +x bootstrap.sh
sudo ./bootstrap.sh
```

2. Follow interactive prompts for role, IP, admin, NAS, etc.

3. Repeat for all manager nodes first, then worker nodes.

4. Verify logs:

```bash
tail -f /var/log/swarm-bootstrap.log
```

---

## Post-Bootstrap Verification

* Check nodes:

```bash
docker node ls
```

* Verify services and timers:

```bash
systemctl list-timers
systemctl status swarm-health.service
systemctl status swarm-manager-sync.service
systemctl status swarm-ufw-sync.service
```

* Confirm `nodes.json` reflects all nodes

---

## Troubleshooting

* Node fails to join → check `swarmd` SSH key access
* Firewall misconfigured → check `swarm-ufw-sync.timer` logs
* Swarm split → ensure only the first manager ran `docker swarm init`
* Candidate label conflicts → review logs
* Logs located at `/var/log/swarm-bootstrap.log` with timestamps

---

## Optional Improvements

* Remove stale firewall rules automatically
* Sync worker IPs immediately after join
* Restrict SSH further based on subnet
* Enable encrypted transport for `nodes.json` updates

---

## Systemd Units Directory — Expected Files

### Health & Recovery

```
swarm-health.service
swarm-health.timer
```

### Manager Sync (nodes.json registry)

```
swarm-manager-sync.service
swarm-manager-sync.timer
```

### UFW Firewall Sync

```
swarm-ufw-sync.service
swarm-ufw-sync.timer
```

### Swarm Auto Join

```
swarm-auto.service
```

### NAS Support (optional)

```
docker-mount-guard.service
docker-mount-guard.timer
```

---


---

## References

* [Docker Swarm Mode Documentation](https://docs.docker.com/engine/swarm/)
* [Swarm Node Management](https://docs.docker.com/engine/swarm/swarm-tutorial/)
* [Firewall and Security Best Practices](https://computingforgeeks.com/docker-swarm-security-guide/)

---


## ❤️ Contributing

Pull requests welcome.
Security improvements especially appreciated.

---

## 📄 License

This project is licensed under the GNU GPLv3 License.
See the LICENSE file for details.
