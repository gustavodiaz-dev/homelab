#!/usr/bin/env bash
set -euo pipefail

source /etc/homelab.env

telegram() {
  local msg="$1"
  [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]] && return 0
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}&text=${msg}&parse_mode=HTML" \
    --max-time 10 > /dev/null || true
}

trap 'telegram "🔴 <b>CT103 apt upgrade falló</b>%0AError en línea $LINENO — revisar: journalctl -u apt-upgrade.service -n 50"' ERR

FECHA=$(date '+%Y-%m-%d')
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "=== apt upgrade CT103 iniciado ==="
apt-get update -qq

UPGRADEABLE=$(apt-get --just-print upgrade 2>/dev/null | grep -c "^Inst" || true)

if [ "$UPGRADEABLE" -gt 0 ]; then
  log "$UPGRADEABLE paquetes a actualizar"
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
  telegram "✅ <b>CT103 apt upgrade</b>%0AFecha: $FECHA%0A$UPGRADEABLE paquetes actualizados"
  log "Upgrade completado"
else
  log "Sin actualizaciones pendientes"
fi

log "=== Listo ==="
