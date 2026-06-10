#!/usr/bin/env bash
set -euo pipefail

N8N_WEBHOOK="${N8N_WEBHOOK_MAINTENANCE:-}"
FECHA=$(date '+%Y-%m-%d')
HERRAMIENTAS_ACTUALIZADAS=""
INSTALACIONES_NUEVAS=""
NOTAS=""
ESTADO="Completado"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

telegram() {
  local msg="$1"
  [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]] && return 0
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}&text=${msg}&parse_mode=HTML" \
    --max-time 10 > /dev/null || true
}

trap 'telegram "🔴 <b>Mantenimiento Desktop falló</b>%0AError inesperado en línea $LINENO — revisar: journalctl --user -u mise-upgrade.service -n 50"' ERR

log "=== Mantenimiento de usuario iniciado ==="

log "--- AUR + Omarchy ---"
if omarchy update git && paru -Syu --aur --noconfirm 2>&1; then
  HERRAMIENTAS_ACTUALIZADAS="AUR actualizado"
else
  NOTAS="Error en AUR/Omarchy update. "
  ESTADO="Parcial"
fi

log "--- mise tools ---"
MISE_ANTES=$(mise list --current 2>/dev/null | awk '{print $1"@"$2}' | sort | tr '\n' ' ')
mise upgrade 2>&1 || true
MISE_DESPUES=$(mise list --current 2>/dev/null | awk '{print $1"@"$2}' | sort | tr '\n' ' ')
if [ "$MISE_ANTES" != "$MISE_DESPUES" ]; then
  HERRAMIENTAS_ACTUALIZADAS="$HERRAMIENTAS_ACTUALIZADAS | mise: $(mise list --current 2>/dev/null | awk '{print $1"@"$2}' | tr '\n' ' ')"
fi

log "--- npm globals ---"
NPM_OUTPUT=$(npm update -g 2>&1 || true)
NPM_CHANGES=$(echo "$NPM_OUTPUT" | grep "changed\|added" | head -3 || true)
if [ -n "$NPM_CHANGES" ]; then
  HERRAMIENTAS_ACTUALIZADAS="$HERRAMIENTAS_ACTUALIZADAS | npm: $NPM_CHANGES"
fi

log "--- Neovim plugins ---"
nvim --headless "+Lazy! update" +qa 2>&1 | grep -v "^$" || true

log "--- pip desactualizado (solo reporte) ---"
PIP_OUTDATED=$(pip list --user --outdated 2>/dev/null | grep -v "^Package\|^---\|^Warning" | awk '{print $1"@"$3}' | tr '\n' ' ' || true)
if [ -n "$PIP_OUTDATED" ]; then
  NOTAS="${NOTAS}pip desactualizado: $PIP_OUTDATED"
fi

log "=== Mantenimiento completado ==="

log "--- Enviando log a Notion via n8n ---"
PAYLOAD=$(jq -n \
  --arg nombre "Mantenimiento Desktop - $FECHA" \
  --arg estado "$ESTADO" \
  --arg instalaciones "$INSTALACIONES_NUEVAS" \
  --arg herramientas "$HERRAMIENTAS_ACTUALIZADAS" \
  --arg notas "$NOTAS" \
  '{nombre: $nombre, tipo: "Desktop", estado: $estado, paquetes_actualizados: 0, instalaciones_nuevas: $instalaciones, herramientas_actualizadas: $herramientas, notas: $notas}')

curl -s -X POST "$N8N_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  --max-time 10 || log "Advertencia: no se pudo enviar log a Notion (n8n no accesible)"

if [ "$ESTADO" != "Completado" ]; then
  telegram "⚠️ <b>Mantenimiento Desktop — $ESTADO</b>%0AFecha: $FECHA%0ANotas: $NOTAS%0ARevisar: journalctl --user -u mise-upgrade.service -n 30"
fi

log "=== Listo ==="
