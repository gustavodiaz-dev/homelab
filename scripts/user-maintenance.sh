#!/usr/bin/env bash
set -euo pipefail

N8N_WEBHOOK="${N8N_WEBHOOK_MAINTENANCE:-}"
FECHA=$(date '+%Y-%m-%d')
HERRAMIENTAS_ACTUALIZADAS=""
INSTALACIONES_NUEVAS=""
NOTAS=""
ESTADO="Completado"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

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
PAYLOAD=$(printf '{"nombre":"Mantenimiento Desktop - %s","tipo":"Desktop","estado":"%s","paquetes_actualizados":0,"instalaciones_nuevas":"%s","herramientas_actualizadas":"%s","notas":"%s"}' \
  "$FECHA" "$ESTADO" "$INSTALACIONES_NUEVAS" "$HERRAMIENTAS_ACTUALIZADAS" "$NOTAS")

curl -s -X POST "$N8N_WEBHOOK" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  --max-time 10 || log "Advertencia: no se pudo enviar log a Notion (n8n no accesible)"

log "=== Listo ==="
