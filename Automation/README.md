# Desert Fish Network Automation

> Enterprise multi-site network automation for Desert Fish — deploying and enforcing consistent configuration across 60 Cisco IOS-XE access switches across London, Paris, and Cairo using a full GitOps workflow, open-source observability stack, and a ContainerLab digital twin for safe pre-production testing.

---

## Overview

This repository contains the full network automation and observability platform for the Desert Fish enterprise network. Every access switch configuration is defined as code, version-controlled in Git, and deployed via Ansible — eliminating manual CLI changes, configuration drift, and undocumented snowflake devices.

**Key capabilities:**

| Capability | Implementation |
|---|---|
| Configuration management | Ansible + Cisco IOS collection + Jinja2 templates |
| Source of truth | NetBox (devices, IPs, VLANs, racks, cables) |
| Config backup | Oxidized → Git (every change is a diff-able commit) |
| Drift detection | Nightly `enforce_compliance.yml` playbook |
| Observability | Prometheus + SNMP Exporter + Grafana + Loki |
| Secrets management | Ansible Vault (AES-256) |
| Pre-production testing | ContainerLab digital twin on dedicated bare-metal server |
| Cloud lab | Oracle Cloud Always Free (Ansible + NetBox on ARM VMs) |

---

## Network Scope

| Site | Location | Access Switches | Management Subnet |
|---|---|---|---|
| London | HQ | 20 × Cisco Catalyst 9300 | 10.10.10.0/24 |
| Paris | Branch | 20 × Cisco Catalyst 9300 | 10.20.10.0/24 |
| Cairo | Branch | 20 × Cisco Catalyst 9300 | 10.30.10.0/24 |

**VLAN scheme** — consistent across all three sites:

| VLAN | Name | Subnet pattern |
|---|---|---|
| 10 | MGMT | 10.{site}.10.0/24 |
| 20 | DATA | 10.{site}.20.0/24 |
| 30 | VOICE | 10.{site}.30.0/24 |
| 40 | WIRELESS | 10.{site}.40.0/24 |
| 50 | GUEST | 10.{site}.50.0/24 |
| 60 | SERVERS | 10.{site}.60.0/24 |
| 99 | NATIVE_BLACKHOLE | — |

---

## Infrastructure Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Oracle Cloud (Always Free)                │
│                                                             │
│  ┌──────────────────────────┐  ┌────────────────────────┐  │
│  │  VM1 — Automation        │  │  VM2 — Source of Truth │  │
│  │  ├─ Ansible + AWX        │  │  ├─ NetBox (IPAM/DCIM) │  │
│  │  ├─ Prometheus           │  │  └─ Oxidized → Git     │  │
│  │  ├─ SNMP Exporter        │  └────────────────────────┘  │
│  │  ├─ Grafana              │                               │
│  │  ├─ Loki + Promtail      │                               │
│  │  └─ Alertmanager         │                               │
│  └──────────────────────────┘                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│             Hetzner Dedicated Server (i7-7700, 64 GB)       │
│             ContainerLab Digital Twin                       │
│  LON-CORE1/2 ── LON-ACC1..20                               │
│  PAR-CORE1/2 ── PAR-ACC1..20     (vrnetlab IOS-XE nodes)   │
│  CAI-CORE1/2 ── CAI-ACC1..20                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   Production Network                        │
│  London ── Paris ── Cairo  (Cisco Catalyst 9300 switches)  │
└─────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
Automation/
│
├── .vscode/
│   ├── extensions.json          # Recommended extensions for VS Code
│   └── settings.json            # Project-specific editor settings
│
├── ansible.cfg                  # Global Ansible configuration
│
├── group_vars/
│   ├── all/
│   │   ├── main.yml             # Variables shared by all 60 switches
│   │   └── vault.yml            # Encrypted secrets (Ansible Vault)
│   ├── london/main.yml          # London site variables
│   ├── paris/main.yml           # Paris site variables
│   └── cairo/main.yml           # Cairo site variables
│
├── host_vars/
│   └── LON-ACC1/main.yml        # Example per-switch variables
│
├── inventories/
│   ├── london/hosts.yml         # London inventory (+ DevNet sandbox)
│   ├── paris/hosts.yml          # Paris inventory
│   ├── cairo/hosts.yml          # Cairo inventory
│   ├── netbox_inventory.yml     # Dynamic inventory from NetBox API
│   └── clab_inventory.yml       # ContainerLab digital twin inventory
│
├── templates/
│   └── access_switch.j2         # Jinja2 template — generates full switch config
│
├── playbooks/
│   ├── deploy_new_switch.yml    # Deploy a brand-new access switch
│   ├── enforce_compliance.yml   # Idempotent drift correction (run nightly)
│   └── netbox_populate.yml      # Seed all devices/sites/VLANs into NetBox
│
├── observability/               # VM1 observability stack (docker-compose)
│   ├── docker-compose.yml
│   ├── prometheus/
│   ├── snmp-exporter/
│   ├── loki/
│   ├── promtail/
│   ├── grafana/
│   └── alertmanager/
│
├── vm2-setup/                   # VM2 source-of-truth stack (docker-compose)
│   ├── docker-compose.yml
│   ├── netbox/
│   └── oxidized/
│
└── clab/
    └── desert-fish-twin.clab.yml  # ContainerLab full topology definition
```

---

## Tool Stack

| Layer | Tool | Why chosen |
|---|---|---|
| Config management | **Ansible** + `cisco.ios` | Agentless, idempotent, industry standard for IOS-XE |
| Templating | **Jinja2** | One template generates correct config for all 60 switches |
| Secrets | **Ansible Vault** | AES-256 encryption at rest, no plaintext credentials in Git |
| Source of truth | **NetBox** | REST API-driven IPAM/DCIM; Ansible queries it for dynamic inventory |
| Config backup | **Oxidized** | SSH-polls every switch hourly, commits to Git with full diff history |
| Metrics | **Prometheus** + **SNMP Exporter** | SNMPv3 AuthPriv polling at 60s intervals |
| Dashboards | **Grafana** | Single pane of glass across all three sites |
| Logs | **Loki** + **Promtail** | Syslog ingestion from IOS-XE; lighter than ELK at this scale |
| Digital twin | **ContainerLab** + **vrnetlab** | GitOps-native topology YAML; IOS-XE in Docker via QEMU |
| Cloud lab | **Oracle Cloud Free** | Genuinely free forever (ARM A1, 4 OCPU, 24 GB RAM) |

---

## Security Features Deployed

Every access switch is configured with:

- **802.1X + MAB** — dot1x authenticator on all user ports with MAB fallback; RADIUS to dual ISE VMs
- **TACACS+** — centralised device administration with per-command authorisation and full accounting
- **SNMPv3 AuthPriv** — SHA auth + AES-128 privacy; no SNMPv1/v2c community strings
- **DHCP Snooping** — all access ports untrusted; uplink trunks trusted
- **Dynamic ARP Inspection (DAI)** — bound to DHCP Snooping binding table
- **STP hardening** — `rapid-pvst`, `portfast default`, `bpduguard default`
- **Unused port shutdown** — all unallocated ports administratively down in VLAN 999
- **Management ACL** — VTY access restricted to management subnets only (10.{site}.10.0/24)
- **SSH v2 only** — `transport input ssh`, minimum key length 2048 bits

---

## Quick Start

### Prerequisites

- Ansible control node (Oracle VM1) with `cisco.ios` and `netbox.netbox` collections
- Ansible Vault password file at `~/.vault_pass`
- NetBox running on Oracle VM2 (populated via `netbox_populate.yml`)

### 1. Clone and configure

```bash
git clone git@github.com:YOUR_USERNAME/desert-fish-automation.git
cd desert-fish-automation/Automation
```

Edit `group_vars/all/vault.yml` with your credentials:

```bash
ansible-vault edit group_vars/all/vault.yml --vault-password-file ~/.vault_pass
```

### 2. Test against the free DevNet sandbox (no production risk)

```bash
# Dry-run against the Cisco DevNet Always-On IOS-XE sandbox
ansible-playbook playbooks/deploy_new_switch.yml \
  -i inventories/london/hosts.yml \
  --limit DEVNET-IOSXE \
  --vault-password-file ~/.vault_pass \
  --check
```

### 3. Test against the ContainerLab digital twin

```bash
# On the Hetzner server:
clab deploy -t clab/desert-fish-twin.clab.yml

# Run playbook against the lab:
ansible-playbook playbooks/deploy_new_switch.yml \
  -i inventories/clab_inventory.yml \
  --limit LON-ACC1 \
  --vault-password-file ~/.vault_pass \
  --check
```

### 4. Deploy to production

```bash
# Using NetBox dynamic inventory (all active access switches):
ansible-playbook playbooks/deploy_new_switch.yml \
  -i inventories/netbox_inventory.yml \
  --limit site_london \
  --vault-password-file ~/.vault_pass
```

### 5. Enforce compliance (run nightly via AWX)

```bash
ansible-playbook playbooks/enforce_compliance.yml \
  -i inventories/netbox_inventory.yml \
  --vault-password-file ~/.vault_pass
```

---

## Change Workflow

Every configuration change follows this path — no direct CLI changes on production switches:

```
Edit code (Mac)
    │
    ▼
git push → GitHub
    │
    ▼
git pull on Hetzner server
    │
    ▼
clab deploy → ContainerLab digital twin
    │
    ▼
ansible-playbook --check (dry-run on lab)
    │
    ▼
ansible-playbook (apply to lab, verify show commands)
    │
    ▼
ansible-playbook (apply to production via NetBox dynamic inventory)
    │
    ▼
Oxidized detects config change → Git commit with diff
```

---

## Documentation

| Document | Description |
|---|---|
| `Network_Automation_Guide.docx` | Beginner-friendly guide: tool choices, Oracle Cloud setup, Jinja2 explained, step-by-step playbook execution |
| `Hetzner_Server_Setup_Guide.docx` | Complete Hetzner server setup: Ubuntu install, Docker, KVM, ContainerLab, vrnetlab IOS-XE build |
| `VSCode_Setup_Guide.docx` | VS Code Remote SSH setup for work and personal MacBooks |

---

## Cloud Cost

| Component | Tool | Monthly Cost |
|---|---|---|
| Automation + Observability (VM1) | Oracle Cloud Always Free | **$0** |
| NetBox + Oxidized (VM2) | Oracle Cloud Always Free | **$0** |
| ContainerLab Digital Twin | Hetzner Server Auction | **~€35** |
| **Total** | | **~$38/month** |

---

## Tested Against

- Cisco IOS-XE 17.3.x (DevNet Always-On Sandbox)
- Cisco IOS-XE 17.06.x (ContainerLab vrnetlab)
- Ansible Core 2.16+
- `cisco.ios` collection 5.x
- NetBox 3.7

---

*Desert Fish Network Automation — Internal use only.*
