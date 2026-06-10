# homelab

Self-hosted infrastructure running on Proxmox VE — automated, monitored, and accessible from anywhere via Tailscale.

## Architecture

```
CachyOS Desktop (Tailscale: 100.108.109.78)
└── Tailscale VPN ──────────────────────────────────────────────────────┐
                                                                        │
Proxmox VE 9.2.0 — MacBook i5 / 16 GB RAM / 100 GB NVMe (192.168.18.15)     │
├── ProxMenux Monitor :8008  (host health — CPU, RAM, SMART, updates)  │
├── CT 100: AdGuard :80/:53  (DNS + ad blocking, *.lab wildcard)       │
├── CT 101: Tailscale        (subnet router → 192.168.18.0/24)         │
└── CT 103: services :80/:443 (Docker stack) ──────────────────────────┘
    ├── Nginx Proxy Manager  (reverse proxy + Let's Encrypt)
    ├── n8n + PostgreSQL      (workflow automation)
    ├── Vaultwarden           (password manager)
    ├── Homepage              (dashboard)
    ├── Uptime Kuma           (service monitoring)
    └── Portainer             (Docker management UI)
```

## Services

| Service | URL | Purpose |
|---------|-----|---------|
| Homepage | `home.lab` | Central dashboard with live metrics |
| n8n | `gdn8n.duckdns.org` | Workflow automation (external) |
| Vaultwarden | `labpass.duckdns.org` | Password manager (external) |
| Nginx Proxy Manager | `npm.lab` | Reverse proxy admin |
| Uptime Kuma | `uptime.lab` | Service uptime monitoring |
| Portainer | `portainer.lab` | Docker container management |
| AdGuard Home | `adguard.lab` | DNS filtering dashboard |
| ProxMenux Monitor | `monitor.lab` | Proxmox host health dashboard |
| Proxmox UI | `proxmox.lab` | Hypervisor management |

All `.lab` subdomains resolve via AdGuard's wildcard DNS rewrite (`*.lab → 192.168.18.29`) and are proxied through NPM — no split-brain DNS, no manual host entries.

## Automation

Unattended tasks that run on schedule:

| Task | Schedule | What it does |
|------|----------|-------------|
| Desktop maintenance | Sundays 4am | AUR, Omarchy, mise, npm globals, nvim plugins → logs to Notion |
| Homelab health check | Daily 8am | Checks Proxmox nodes, containers, backups → Telegram if issue |
| Weekly report | Sundays 5am | Full status → Notion + Telegram summary |
| Monthly report | 1st of month 8am | Systems health report → Notion + Telegram |

Alerts are delivered to Telegram via two independent paths:
- **Uptime Kuma** — HTTP endpoint monitoring (service up/down)
- **ProxMenux Monitor** — Proxmox host health (SMART, memory, updates, security)

## Notifications

All alerts go to a private Telegram bot (`@Homelab_gustavo_bot`). No email, no noise — just actionable messages when something needs attention.

## Stack

| Layer | Technology |
|-------|-----------|
| Hypervisor | Proxmox VE on bare metal |
| Containers | LXC (lightweight, no VM overhead) |
| Docker runtime | Docker Engine inside CT 103 |
| Compose | Docker Compose v2 |
| Reverse proxy | Nginx Proxy Manager |
| DNS | AdGuard Home (local) + DuckDNS (external) |
| VPN | Tailscale (remote access + subnet routing) |
| Monitoring | Uptime Kuma + ProxMenux Monitor |
| Automation | n8n (self-hosted) |
| Secrets | Vaultwarden + `.env` files (never in git) |
| Backups | Proxmox Backup Server (Tuxis, offsite, encrypted, daily 03:30) |
| Notifications | Telegram Bot API |

## Repository layout

```
homelab/
├── docker-compose.services.yml   # Full CT 103 Docker stack
├── homepage-services.yaml        # Homepage dashboard config
├── scripts/
│   ├── user-maintenance.sh       # Weekly desktop maintenance
│   ├── voz-claude.sh             # Voice assistant (push-to-talk → Whisper → Claude → TTS)
│   ├── claude-tts-bridge.py      # Streaming TTS bridge for Claude CLI
│   ├── whisper-server.py         # Whisper transcription server (Unix socket)
│   └── gamepad-voz.py            # GuliKit gamepad paddle → voice trigger
└── systemd/                      # User-level systemd units and timers
```

## Roadmap

| Phase | Status | What |
|-------|--------|------|
| 0 — Hardening | Done | PBS backup, firewall, kernel cleanup |
| 1 — Repurposing ZimaOS | Done | Migrated to LXC + Docker on CT 103 |
| 2 — Service stack | Done | Dashboard, monitoring, proxy, password manager |
| 3 — k3s | Next | Kubernetes node on CT 106 (CKA prep) |
| 4 — Terraform + Ansible | Pending | IaC over existing stack |
| 5 — Observability | Pending | Prometheus + Grafana + Loki |

## Security notes

- All secrets loaded from `EnvironmentFile` — never hardcoded
- Vaultwarden behind NPM with rate limiting and signups disabled
- n8n bound to LAN IP only (`192.168.18.29:5678`, not `0.0.0.0`)
- PBS backups encrypted with a key stored in Vaultwarden + physical copy
- Tailscale ACLs restrict which devices can reach which services
