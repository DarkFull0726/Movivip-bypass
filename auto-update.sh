#!/bin/bash
# Auto-update desactivado — instalación sin licencia (uso interno)
exit 0

#=========================================================
#   MOVIVIP NETWORK — AUTO-UPDATE CHECKER v7.0 (RELEASE + SHA256)
#   Verifica actualizaciones periodicamente
#   Solo descarga si licencia activa
#   Instala silenciosamente en background
#
#   NUEVO v7.0 — DISTRIBUCIÓN VÍA GITHUB RELEASE (SIN git clone):
#   🔒 El código viaja SOLO en el instalador ofuscado (asset de la release).
#   🛡 SHA256 del instalador se verifica ANTES de ejecutar.
#   💾 El instalador (--update) hace backup + preserva config/licencia/usuarios.
#   ⚠ Si la release aún no está publicada → no descarga, loguea y sale limpio.
#
#   MOTOR DE INTEGRIDAD (heredado):
#   🧹 Repara BOM invisible en cada ejecucion (sin reinstalar)
#   🔍 Detecta errores de sintaxis y los registra
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
LICENCIA="$BASE/licencia.conf"
LOG="$BASE/logs/auto-update.log"
LOCK="/tmp/movivip_autoupdate.lock"
VERSION_FILE="$BASE/version.txt"
RAW_VER="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/version.txt"
REL_URL="https://github.com/studioanime977/MoviVIPNetwork/releases/latest/download"

# Evitar ejecuciones duplicadas
[[ -f "$LOCK" ]] && { AGE=$(( $(date +%s) - $(stat -c %Y "$LOCK" 2>/dev/null || echo 0) )); [[ $AGE -lt 3600 ]] && exit 0; }
echo $$ > "$LOCK"
trap "rm -f '$LOCK'" EXIT

mkdir -p "$BASE/logs" "$BASE/backups"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

log "=== Auto-update check iniciado ==="

#==============================
# VERSIONES
#==============================

LOCAL_VER=$(tr -d ' \n' < "$VERSION_FILE" 2>/dev/null || echo "0")
REMOTE_VER=$(curl -fsSL --max-time 5 "$RAW_VER" 2>/dev/null | tr -d ' \n')
[[ -z "$REMOTE_VER" ]] && REMOTE_VER=$(curl -fsSL --max-time 8 "https://api.github.com/repos/studioanime977/MoviVIPNetwork/contents/version.txt" 2>/dev/null \
    | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4 | base64 -d 2>/dev/null | tr -d ' \n')

if [[ -z "$REMOTE_VER" ]]; then
    log "No se pudo obtener versión remota"
    exit 0
fi

if [[ "$LOCAL_VER" == "$REMOTE_VER" ]]; then
    log "Ya actualizado (v${LOCAL_VER})"
    exit 0
fi

# Orden semántico simple
l1=${LOCAL_VER%%.*}; r1=${REMOTE_VER%%.*}
if [[ $r1 -lt $l1 ]]; then
    log "Remota (${REMOTE_VER}) anterior a local (${LOCAL_VER}) — ignorando"
    exit 0
fi

log "Nueva versión: v${LOCAL_VER} → v${REMOTE_VER}"

#==============================
# VERIFICAR LICENCIA
#==============================

if [[ ! -f "$LICENCIA" ]]; then
    log "Sin archivo de licencia — saltando"
    exit 0
fi

source "$LICENCIA" 2>/dev/null

[[ -z "$KEY" ]] && { log "Sin KEY configurada — saltando"; exit 0; }
[[ "$LICENCIA_ACTIVA" == "false" ]] && { log "Licencia desactivada — saltando"; exit 0; }

# Verificar expiración local
if [[ "$EXPIRA" != "0" && -n "$EXPIRA" ]]; then
    EXPIRA_TS=$(date -d "$EXPIRA" +%s 2>/dev/null || echo 0)
    NOW_TS=$(date +%s)
    if [[ $EXPIRA_TS -gt 0 && $NOW_TS -gt $EXPIRA_TS ]]; then
        log "Licencia vencida local ($EXPIRA) — saltando"
        exit 0
    fi
fi

# Verificación online contra Firebase (fail-open si no hay respuesta)
FB_BASE="movivip-network-default-rtdb.firebaseio.com"
# FIX v6.6: keys v2 contienen '+' y '/'; Firebase no los acepta en paths.
FB_KEY_PATH=$(echo "$KEY" | tr '+/' '-_')
FB_URL="https://${FB_BASE}/licencias_movivip/${FB_KEY_PATH}.json"
FB_DATA=$(curl -fsSL --max-time 10 "$FB_URL" 2>/dev/null)

if [[ -n "$FB_DATA" ]]; then
    FB_ACTIVA=$(echo "$FB_DATA" | grep -o '"activa":[[:space:]]*true' | head -1)
    if [[ -z "$FB_ACTIVA" ]]; then
        log "Firebase: licencia inactiva — saltando"
        exit 0
    fi

    FB_EXPIRA=$(echo "$FB_DATA" | grep -o '"expira":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
    if [[ -n "$FB_EXPIRA" && "$FB_EXPIRA" != "0" ]]; then
        FB_EXPIRA_TS=$(date -d "$FB_EXPIRA" +%s 2>/dev/null || echo 0)
        NOW_TS=$(date +%s)
        if [[ $FB_EXPIRA_TS -gt 0 && $NOW_TS -gt $FB_EXPIRA_TS ]]; then
            log "Firebase: licencia vencida ($FB_EXPIRA) — saltando"
            exit 0
        fi
    fi
else
    log "Sin respuesta Firebase — fall-open, continuando"
fi

#==============================
# 🧹 MOTOR DE INTEGRIDAD (pre-chequeo rápido)
#==============================
INTEG_DIR="/tmp/movivip_integ_$$"

reparar_bom() {
    local f="$1"
    [ "$(od -A n -t x1 -N 3 "$f" 2>/dev/null | tr -d ' \n')" = "efbbbf" ] || return 1
    local perms
    perms=$(stat -c%a "$f" 2>/dev/null || echo 755)
    local tmp="$INTEG_DIR/bom.tmp"
    mkdir -p "$INTEG_DIR"
    tail -c +4 "$f" > "$tmp"
    sed -i '/./,$!d' "$tmp"
    cat "$tmp" > "$f"
    rm -f "$tmp"
    chmod "$perms" "$f"
    return 0
}

#==============================
# DESCARGAR RELEASE + VERIFICAR SHA256
#==============================

TEMP_DIR="/tmp/movivip_autoupdate_$$"
mkdir -p "$TEMP_DIR"

curl -fL --max-time 180 --retry 3 -o "$TEMP_DIR/install.sh" "$REL_URL/install.sh" 2>/dev/null
if [[ $? -ne 0 ]]; then
    log "Error al descargar instalador de la release (¿release publicada?)"
    rm -rf "$TEMP_DIR"
    exit 1
fi

curl -fL --max-time 60 --retry 2 -o "$TEMP_DIR/install.sh.sha256" "$REL_URL/install.sh.sha256" 2>/dev/null
GOT=$(sha256sum "$TEMP_DIR/install.sh" 2>/dev/null | awk '{print $1}')
EXP=$(awk '{print $1}' "$TEMP_DIR/install.sh.sha256" 2>/dev/null)
if [[ -z "$EXP" || "$GOT" != "$EXP" ]]; then
    log "SHA256 NO coincide (got=$GOT exp=$EXP) — paquete rechazado"
    rm -rf "$TEMP_DIR"
    exit 1
fi
log "SHA256 verificado (${GOT:0:20}...)"

# Backup completo antes de tocar nada (sin logs ni backups previos)
BK="$BASE/backups/auto_$(date +%Y%m%d_%H%M%S).tar.gz"
tar czf "$BK" -C /etc --exclude='movivip/logs' --exclude='movivip/backups' movivip 2>/dev/null
log "💾 Backup pre-actualizacion: $BK ($(du -h "$BK" 2>/dev/null | cut -f1))"

# Retención: mantener SOLO los 3 backups automáticos más recientes (evita llenar disco)
ls -1t "$BASE"/backups/auto_*.tar.gz 2>/dev/null | tail -n +4 | xargs -r rm -f 2>/dev/null
BK_KEPT=$(ls -1 "$BASE"/backups/auto_*.tar.gz 2>/dev/null | wc -l)
[[ "$BK_KEPT" -gt 0 ]] && log "🧹 Retención de backups automáticos: ${BK_KEPT}/3"

# Aplicar con el instalador (él preserva config/licencia/usuarios ZipVPN+Xray)
bash "$TEMP_DIR/install.sh" --update >> "$LOG" 2>&1
RC=$?
rm -rf "$TEMP_DIR"

if [[ $RC -ne 0 ]]; then
    log "Instalador reportó error ($RC) — se conserva la instalación anterior"
    exit 1
fi

# Fix CRLF from Windows + verificacion final de integridad
find "$BASE" -name "*.sh" -type f ! -path "$BASE/backups/*" -exec sed -i 's/\r$//' {} + 2>/dev/null

# Tras actualizar, garantizar el cron de limpieza de cuentas V2Ray
# expiradas en VPS ya desplegados (sin necesidad de reinstalar).
if [[ -f "$BASE/protocolos/v2ray.sh" ]]; then
    bash "$BASE/protocolos/v2ray.sh" --ensure-cleanup 2>/dev/null || true
fi

# iptables gaming
IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
[[ -z "$IFACE" ]] && IFACE="eth0"

for RULE in "7000:7999" "3478:3480" "8000:9000"; do
    iptables -t mangle -C PREROUTING -p udp --dport "$RULE" -j DSCP --set-dscp-class af41 2>/dev/null || \
        iptables -t mangle -A PREROUTING -p udp --dport "$RULE" -j DSCP --set-dscp-class af41
done

iptables -N MOVIVIP_OUT >/dev/null 2>&1
iptables -C OUTPUT -j MOVIVIP_OUT >/dev/null 2>&1 || iptables -I OUTPUT 1 -j MOVIVIP_OUT
iptables-save > /etc/iptables/rules.v4 2>/dev/null

log "✅ Actualización completada: v${LOCAL_VER} → v${REMOTE_VER} (release protegida)."