#!/usr/bin/env bash
set -euo pipefail

source /etc/homelab.env

CT=103
FECHA=$(date '+%Y-%m-%d')
ACTUALIZADAS=""
ERRORES=""

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

telegram() {
  local msg="$1"
  [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]] && return 0
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}&text=${msg}&parse_mode=HTML" \
    --max-time 10 > /dev/null || true
}

trap 'telegram "🔴 <b>update-docker falló</b>%0AError en línea $LINENO — revisar: journalctl -u update-docker.service -n 50"' ERR

update_stack() {
  local dir="$1"
  local name
  name=$(basename "$dir")

  log "--- Checking $name ---"

  # Pull remote images; capture which ones changed
  local pull_out
  pull_out=$(pct exec "$CT" -- bash -c "cd $dir && docker compose pull --quiet 2>&1" || true)

  # docker compose pull prints "Pulled" lines only for updated images
  local updated_images
  updated_images=$(echo "$pull_out" | grep -i "Pulled\|Downloaded newer" | sed 's/.*\s//' | tr '\n' ' ' | xargs || true)

  if [ -n "$updated_images" ]; then
    log "$name: imágenes nuevas — $updated_images"
    pct exec "$CT" -- bash -c "cd $dir && docker compose up -d --remove-orphans --quiet-pull"
    ACTUALIZADAS="$ACTUALIZADAS%0A📦 <b>$name</b>: $updated_images"
  else
    log "$name: sin cambios"
  fi
}

log "=== update-docker iniciado ==="

update_stack /opt/docker/services || { ERRORES="$ERRORES services"; log "ERROR en services"; }

log "--- Limpiando imágenes huérfanas ---"
FREED=$(pct exec "$CT" -- docker image prune -f --format '{{.SpaceReclaimed}}' 2>/dev/null || true)
[ -n "$FREED" ] && log "Espacio liberado: $FREED"

log "=== Listo ==="

if [ -n "$ERRORES" ]; then
  telegram "🔴 <b>update-docker falló</b>%0AFecha: $FECHA%0AStacks con error:$ERRORES"
elif [ -n "$ACTUALIZADAS" ]; then
  telegram "🐳 <b>Docker images actualizadas</b>%0AFecha: $FECHA$ACTUALIZADAS"
fi
