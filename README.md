# homelab

Autonomous infrastructure stack — Proxmox · n8n · Telegram · Notion

Everything runs unattended. Daily health checks, weekly reports, monthly summaries — all delivered to Telegram without lifting a finger.

## Architecture

```
CachyOS Desktop
├── systemd timers → maintenance scripts → n8n webhook → Notion
└── Tailscale → Proxmox homelab
                ├── CT 100: AdGuard (DNS)
                ├── CT 101: Tailscale (routing)
                └── CT 103: n8n (automation hub)
```

## What's running

| Workflow | Schedule | What it does |
|----------|----------|-------------|
| Desktop maintenance | Sundays 4am | AUR, Omarchy, mise, npm, nvim plugins → logs to Notion |
| Homelab monitor | Daily 8am | Checks Proxmox nodes, containers, backups → Telegram if issue |
| Weekly homelab report | Sundays 5am | Full status → Notion + Telegram summary |
| Monthly systems report | 1st of month 8am | Full health report → Notion + Telegram |

## Scripts (`scripts/`)

| Script | Description |
|--------|-------------|
| `user-maintenance.sh` | Weekly desktop maintenance — updates tools and logs results to n8n |
| `voz-claude.sh` | Voice assistant — push-to-talk → Whisper STT → Claude → Piper TTS |
| `claude-tts-bridge.py` | Streaming bridge between Claude CLI output and TTS |
| `whisper-server.py` | Whisper transcription server via Unix socket |
| `gamepad-voz.py` | GuliKit gamepad paddle → voice assistant trigger |

## Systemd units (`systemd/`)

User-level timers and services for all scheduled tasks. All secrets are loaded from `EnvironmentFile` — never hardcoded.

## Setup

### 1. Secrets

```bash
cp .env.example ~/.config/gus-monitor.env
chmod 600 ~/.config/gus-monitor.env
# Edit and fill in your values
```

### 2. Systemd units

```bash
cp systemd/*.service systemd/*.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now mise-upgrade.timer
```

### 3. n8n

Deploy n8n on your homelab and import the workflows from the [n8n-workflows](https://github.com/gustavodiaz-gif/n8n-workflows) repo.

## Stack

- **Homelab:** Proxmox VE + LXC containers
- **Automation:** n8n (self-hosted)
- **Notifications:** Telegram Bot API
- **Storage:** Notion databases
- **VPN:** Tailscale
- **OS:** CachyOS Linux
