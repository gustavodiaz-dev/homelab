#!/usr/bin/env bash
set -euo pipefail

source /etc/homelab.env

CONTAINERS=(100 101 103 104)
FECHA=$(date '+%Y-%m-%d')
RESUMEN=""
ERRORES=""

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

telegram() {
  local msg="$1"
  [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]] && return 0
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}&text=${msg}&parse_mode=HTML" \
    --max-time 10 > /dev/null || true
}

upgrade_ct() {
  local ctid="$1"
  local name
  name=$(pct config "$ctid" | grep '^hostname:' | awk '{print $2}' || echo "CT$ctid")

  log "--- Upgrading CT$ctid ($name) ---"

  if ! pct status "$ctid" | grep -q running; then
    log "CT$ctid no está corriendo, omitiendo"
    RESUMEN="$RESUMEN%0A⏭ CT$ctid ($name): apagado"
    return 0
  fi

  pct exec "$ctid" -- apt-get update -qq

  local count
  count=$(pct exec "$ctid" -- bash -c 'apt-get --just-print upgrade 2>/dev/null | grep -c "^Inst" || true')

  if [ "${count:-0}" -gt 0 ]; then
    DEBIAN_FRONTEND=noninteractive pct exec "$ctid" -- apt-get upgrade -y -qq
    log "CT$ctid: $count paquetes actualizados"
    RESUMEN="$RESUMEN%0A✅ CT$ctid ($name): $count actualizados"
  else
    log "CT$ctid: sin actualizaciones"
    RESUMEN="$RESUMEN%0A🔵 CT$ctid ($name): al día"
  fi
}

log "=== upgrade-containers iniciado ==="

for ctid in "${CONTAINERS[@]}"; do
  upgrade_ct "$ctid" || {
    log "ERROR en CT$ctid"
    ERRORES="$ERRORES CT$ctid"
    RESUMEN="$RESUMEN%0A❌ CT$ctid: error"
  }
done

log "=== Listo ==="

if [ -n "$ERRORES" ]; then
  telegram "🔴 <b>upgrade-containers falló</b>%0AFecha: $FECHA%0AErrores en:$ERRORES%0A$RESUMEN%0ARevisar: journalctl -u upgrade-containers.service -n 50"
elif echo "$RESUMEN" | grep -q "actualizados"; then
  telegram "📦 <b>Containers actualizados</b>%0AFecha: $FECHA$RESUMEN"
fi
