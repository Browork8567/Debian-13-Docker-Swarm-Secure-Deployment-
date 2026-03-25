# Docker-Swarm-Bootstrap-for-Debian

Automated, secure, and self-healing Docker Swarm bootstrap system for Debian.


![Security](https://img.shields.io/github/actions/workflow/status/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-/security.yml?branch=main\&label=Security\&style=flat-square)
![Last Commit](https://img.shields.io/github/last-commit/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-?style=flat-square)
![Issues](https://img.shields.io/github/issues/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-?style=flat-square)
![License](https://img.shields.io/github/license/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-?style=flat-square)

[![Deploy](https://img.shields.io/badge/Deploy-Homelab-blue?style=for-the-badge)](https://github.com/Browork8567/Debian-13-Docker-Swarm-Secure-Deployment-)

---

# 📑 Table of Contents

- [📌 Overview](#-overview)
- [📈 Use Cases](#-use-cases)
- [✨ Key Features](#-key-features)
- [🏗 Architecture](#-architecture)
- [📂 Core Script Workflow](#-core-script-workflow-authoritative)
- [⚙️ Interactive Configuration](#️-interactive-configuration)
- [🧠 Swarm Initialization Logic](#-swarm-initialization-logic)
- [🌐 Node Registry System](#-node-registry-system)
- [🔐 Security Model](#-security-model)
- [🔄 Health Checks & Auto-Recovery](#-health-checks--auto-recovery)
- [🧩 Manager Promotion Strategy](#-manager-promotion-strategy)
- [📜 Logging](#-logging)
- [⚠️ Important Notes](#️-important-notes)
- [🚀 Installation](#-installation)
- [✅ Recommended Deployment Order](#-recommended-deployment-order)
- [🔍 Verification](#-verification)
- [🧹 Design Decisions](#-design-decisions)
- [❤️ Contributing](#️-contributing)
- [📄 License](#-license)

...

---

# 📌 Overview

Automated, modular bootstrap system for deploying a **production-ready Docker Swarm cluster** on fresh Debian hosts.

This project transforms a bare VM into a fully configured swarm node with:

* Multi-manager support
* Automated node discovery
* Secure SSH orchestration
* Health checks & self-recovery
* Dynamic firewall synchronization
* Minimal manual intervention

This repository provides a **deterministic, race-condition-safe deployment workflow** for Docker Swarm clusters.

---

# 📈 Use Cases

* Homelab cluster automation
* On-prem VM swarm deployment
* Edge compute clusters
* Rapid rebuild environments

---

# ✨ Key Features

### 🔧 Fully Automated Bootstrap

* One-command deployment from fresh Debian install
* Interactive configuration collected once, reused everywhere

### 🧠 Deterministic Swarm Initialization

* Explicit **primary manager designation**
* Eliminates split-brain swarm creation

### 🔐 Secure Automation Model

* Dedicated `swarmd` service account
* Restricted SSH keys (no shell, no forwarding)
* Principle of least privilege applied

### 🔄 Self-Healing Cluster Behavior

* Health checks via systemd timers
* Automatic node rejoin
* Controlled manager promotion

### 🌐 Dynamic Network Awareness

* Central `nodes.json` registry
* Automatic UFW rule synchronization across cluster

### 🧩 Modular Script Design

* Clean separation of responsibilities
* Easy to extend or disable components

---

# 🏗 Architecture

```text
Fresh Debian VM
      │
      ▼
bootstrap.sh
      │
      ▼
01-config.sh        → Collect all inputs (role, IP, admin, primary manager)
02-dependencies.sh  → Install Docker, jq, SSH tools
04-swarm-user.sh    → Create restricted swarmd automation account
05-ssh.sh           → Establish inter-node SSH trust
06-ufw.sh           → Apply initial firewall rules (permissive bootstrap mode)
07-nas.sh           → Optional NAS configuration
08-swarm.sh         → Initialize or join Docker Swarm (race-safe)
09-hardening.sh     → Security hardening (Fail2Ban, sysctl)

      ▼
Systemd Runtime Layer
      ├── swarm-health.timer
      ├── swarm-manager-sync.timer
      ├── swarm-ufw-sync.timer
      └── docker-mount-guard.timer
```

---

# 📂 Core Script Workflow (Authoritative)


| Order | Script               | Purpose                                                                  |
| ----- | -------------------- | ------------------------------------------------------------------------ |
| 01    | `01-config.sh`       | Collects all user input and generates `/etc/swarm-bootstrap/config.json` |
| 02    | `02-dependencies.sh` | Installs Docker, jq, openssh-client (merged base logic)                  |
| 04    | `04-swarm-user.sh`   | Creates `swarmd` service account (no-login, docker group)                |
| 05    | `05-ssh.sh`          | Configures SSH trust between nodes using restricted keys                 |
| 06    | `06-ufw.sh`          | Applies initial firewall rules (broad, bootstrap-safe)                   |
| 07    | `07-nas.sh`          | Optional NAS setup                                                       |
| 08    | `08-swarm.sh`        | Initializes or joins swarm using primary manager logic                   |
| 09    | `09-hardening.sh`    | Applies system hardening                                                 |
| —     | `bootstrap.sh`       | Orchestrates execution + logging                                         |

---

# ⚙️ Interactive Configuration

Executed once at the start:

* Node role (`manager` / `worker`)
* Node IP address
* Admin username
* Admin IP (for SSH access restriction)
* **Primary manager designation (critical for cluster stability)**

All values are stored in:

```bash
/etc/swarm-bootstrap/config.json
```

---

# 🧠 Swarm Initialization Logic (Race-Condition Safe)

To prevent **split-cluster scenarios**, the system enforces:

### ✅ Primary Manager Model

* Only ONE node is marked:

```json
"is_primary_manager": true
```

### Behavior:

| Node Type       | Action                     |
| --------------- | -------------------------- |
| Primary Manager | Runs `docker swarm init`   |
| Other Managers  | Join as managers via token |
| Workers         | Join as workers            |

---

### Why This Matters

Without this:

* Multiple managers may initialize independent swarms
* Cluster becomes permanently fragmented

---

# 🌐 Node Registry System

Central registry:

```bash
/etc/swarm-bootstrap/nodes.json
```

Example:

```json
{
  "managers": ["10.0.0.1", "10.0.0.2"],
  "workers": ["10.0.0.3", "10.0.0.4"]
}
```

---

## 🔄 How It Works

* Maintained by **leader manager only**
* Updated via:

```
swarm-manager-sync.service
```

* Used by:

  * SSH trust propagation
  * Firewall synchronization
  * Cluster awareness logic

---

# 🔐 Security Model

### 👤 `swarmd` Automation Account

* No shell access (`/usr/sbin/nologin`)
* Member of `docker` group
* Used only for:

  * SSH orchestration
  * Swarm token retrieval

---

### 🔑 SSH Restrictions

Keys are restricted with:

```text
no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-pty
```

---

### 🔥 Firewall Design

**Bootstrap Phase:**

* Broad internal allow rules
* Prevents early communication failures

**Runtime Phase:**

* Tightened automatically via:

```
swarm-ufw-sync.timer
```

---

### Access Model

| Node Type | Allowed Access                          |
| --------- | --------------------------------------- |
| Managers  | Admin IP + other managers               |
| Workers   | Admin IP (inbound), managers (outbound) |

---

# 🔄 Health Checks & Auto-Recovery

Systemd-driven:

| Service                      | Purpose                           |
| ---------------------------- | --------------------------------- |
| `swarm-health.service`       | Detects failures and rejoin nodes |
| `swarm-manager-sync.service` | Updates node registry             |
| `swarm-ufw-sync.service`     | Synchronizes firewall rules       |
| `docker-mount-guard.service` | Maintains NAS mounts              |

---

### Behavior

* Nodes rejoin swarm after reboot
* Cluster maintains quorum automatically
* Single-node promotion allowed if quorum at risk

---

# 🧩 Manager Promotion Strategy

Workers can be labeled:

```text
node.labels.role=manager-candidate01
node.labels.role=manager-candidate02
```

### Rules:

* Only **one promotion at a time**
* Prevents election storms
* Maintains predictable recovery behavior

---

# 📜 Logging

All bootstrap activity logged to:

```bash
/var/log/swarm-bootstrap.log
```

Useful for:

* Debugging failed joins
* Tracking script execution
* Auditing setup

---

# ⚠️ Important Notes

* Only ONE node should be marked as primary manager
* Ensure SSH connectivity between nodes
* Admin IP must be correct to avoid lockout
* Workers must reach managers over port `2377`

---

# 🚀 Installation

Run on each node:

```bash
curl -fsSL https://raw.githubusercontent.com/Browork8567/Docker-Swarm-Bootstrap-Debian/main/bootstrap.sh -o bootstrap.sh
chmod +x bootstrap.sh
sudo ./bootstrap.sh
```

---

# ✅ Recommended Deployment Order

1. Deploy **Primary Manager**
2. Deploy additional **Managers**
3. Deploy **Workers**

---

# 🔍 Verification

```bash
docker node ls
```

```bash
systemctl list-timers
```

---

# 🧹 Design Decisions

### Why systemd timers?

* Native to OS
* Reliable
* No extra dependencies

### Why JSON instead of env/config files?

* Structured
* Easy to parse with `jq`
* Extensible

### Why not dynamic leader election for init?

* Prevents race conditions
* Ensures deterministic cluster formation



---

## ❤️ Contributing

Pull requests welcome.
Security improvements especially appreciated.

---

## 📄 License

This project is licensed under the GNU GPLv3 License.
See the LICENSE file for details.
