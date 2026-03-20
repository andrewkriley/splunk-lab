# partner-mcp-splunk-lab

Deploy Splunk Enterprise in an Ubuntu 24.04.4 LXC container on Proxmox.

## Overview

This project automates the full lifecycle of a Splunk Enterprise lab environment:

1. Creates an Ubuntu 24.04.4 LXC container on a Proxmox host
2. Installs Splunk Enterprise inside the container
3. Configures HEC, receiving ports, and optional licensing

## Prerequisites

- Proxmox VE host with SSH access
- Ubuntu 24.04 LXC template available (or downloadable via `pveam`)
- SSH key-based auth to the Proxmox host (recommended)
- Splunk Enterprise `.deb` download access (downloaded automatically)

## Setup

1. Copy the example environment file and configure your values:

```bash
cp .env.example .env
```

2. Edit `.env` with your Proxmox host details, container specs, and Splunk credentials.

## Usage

### Full deployment (create container + install + configure)

```bash
bash scripts/deploy.sh
```

### Step-by-step

```bash
# 1. Create the LXC container
bash scripts/create-lxc.sh

# 2. Install Splunk Enterprise
bash scripts/install-splunk.sh

# 3. Configure Splunk (HEC, receiving, license)
bash scripts/configure-splunk.sh
```

### Destroy the lab

```bash
bash scripts/destroy.sh
```

## Configuration

All variables are set in `.env`. See `.env.example` for full reference.

| Variable | Description |
|---|---|
| `PROXMOX_HOST` | Proxmox host IP or hostname |
| `PROXMOX_USER` | Proxmox SSH user (e.g. `root@pam`) |
| `LXC_ID` | Proxmox container ID |
| `LXC_IP` | Container static IP in CIDR notation |
| `SPLUNK_VERSION` | Splunk Enterprise version to install |
| `SPLUNK_ADMIN_PASSWORD` | Splunk admin password |
| `SPLUNK_LICENSE_FILE` | Path to `.license` file (leave blank for trial) |

## Ports

| Port | Service |
|---|---|
| `8000` | Splunk Web UI |
| `8089` | Splunk management API |
| `8088` | HTTP Event Collector (HEC) |
| `9997` | Splunk indexer (forwarder input) |
