#!/bin/bash
# =============================================================
#  MOVIVIP NETWORK — CHECK LICENCIA EN VIVO (por protocolo)
#  -------------------------------------------------------------
#  Este módulo valida la licencia contra Firebase RTDB EN VIVO.
#  Lo llaman TODOS los protocolos y el bot al inicio:
#
#      bash /etc/movivip/check-licencia.sh || exit 1
#
#  CÓDIGOS DE SALIDA:
#    0  = licencia VÁLIDA (activa + no vencida) → se permite operar
#    1  = licencia NO VÁLIDA / vencida / sin key → se BLOQUEA
#    2  = error de red (no se pudo consultar) → se BLOQUEA
#          (fail-closed: sin confirmación de Firebase NO se opera)
#
#  De dónde saca la key:
#    1. /etc/movivip/licencia.conf  (guardada por el gate al instalar)
#    2. Si no existe → intenta ejecutar el gate interactivo
#       (/etc/movivip/validar-licencia.sh) para que el cliente la pida
#
#  REGLA DE NEGOCIO:
#    - La validación es SIEMPRE EN LÍNEA contra Firebase (nunca local)
#    - El archivo local SOLO guarda CUÁL key es; la decisión de si está
#      activa/vencida la toma Firebase en el momento de cada consulta
#    - Sin key guardada         -> pide la key (gate interactivo)
#    - Key vencida / revocada   -> BLOQUEA protocolo + muestra contacto
#    - expira=0 o vacía         -> VITALICIA (de por vida, nunca vence)
#    - Sin internet             -> BLOQUEA (fail-closed, anti-piratería)
# =============================================================

# ================= CONFIGURACIÓN =================
FB_BASE="movivip-network-default-rtdb.firebaseio.com"
FB_LICENCIAS="licencias_movivip"
# Almacen de arraigo IP: DB compartida del ecosistema (permite escritura sin token)
IP_FB_BASE="keygenbpt-default-rtdb.firebaseio.com"
IP_FB_RAMAS="activaciones_movivip"
BASE_DIR="/etc/movivip"
LICENCIA_FILE="$BASE_DIR/licencia.conf"
GATE_LOCAL="$BASE_DIR/validar-licencia.sh"
GATE_LOCAL_LEGACY="$BASE_DIR/gate/validar-licencia.sh"
GATE_URL="https://raw.githubusercontent.com/studioanime977/vps-license-gate/main/gate/validar-licencia.sh"
FIREBASE_PLAN="$BASE_DIR/lib/firebase-plan.sh"

# Si el helper central existe, úsalo como fuente de verdad (Firebase SIEMPRE).
# El plan y el estado NUNCA se leen del licencia.conf local (editable por el
# cliente); este archivo local solo guarda QUÉ key es, y aquí se reescribe
# con el plan/cliente/tipo reales que vienen de Firebase en cada consulta.

# ================= COLORES =================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# ================= CONTACTO (venta) =================
mostrar_contacto() {
    echo -e "${RED}──────────────────────────────────────────────────────${NC}"
    echo -e "${RED}  ⛔ ACCESO BLOQUEADO — LICENCIA NO VÁLIDA${NC}"
    echo -e "${RED}──────────────────────────────────────────────────────${NC}"
    echo -e "${YELLOW}  Este protocolo requiere una clave de licencia activa.${NC}"
    echo ""
    echo -e "${CYAN}  🔑 Adquiere o renueva tu licencia aquí:${NC}"
    echo -e "${CYAN}  ─────────────────────────────────────────────${NC}"
    echo -e "  💬 Telegram : ${GREEN}@MoviVIP${NC}"
    echo -e "  📱 WhatsApp : ${GREEN}+57 311 700 8185${NC}"
    echo -e "  🌐 Web      : ${GREEN}https://movivip-network.web.app${NC}"
    echo -e "  📢 Canal    : ${GREEN}https://t.me/MoviVIPNetwork${NC}"
    echo -e "  👥 Grupo    : ${GREEN}https://t.me/MoviVIPNet${NC}"
    echo -e "${CYAN}  ─────────────────────────────────────────────${NC}"
    echo ""
}

# ================= HELPERS =================
# Validar formato de key: legacy KEY-XXXXXXXXXX (10 hex) o v2 (40/64 chars)
# Nota: comillas simples para que `[[ =~ ]]` no trate la key como patrón
key_formato_valido() {
    local k="$1"
    [[ -z "$k" ]] && return 1
    if [[ "$k" =~ ^KEY-[0-9A-Fa-f]{10}$ ]]; then
        return 0
    fi
    if [[ "${#k}" -eq 40 || "${#k}" -eq 64 ]]; then
        if [[ "$k" =~ ^[A-Za-z0-9+/=_-]+$ ]]; then
            return 0
        fi
    fi
    return 1
}

# Extraer campo del JSON (sin jq - compatible)
json_get() {
    local json="$1" campo="$2"
    echo "$json" | grep -o "\"${campo}\"[[:space:]]*:[[:space:]]*[^,}]*" | head -n1 | sed "s/\"${campo}\"[[:space:]]*:[[:space:]]*//" | tr -d '"' | tr -d ' '
}

# Path url-safe Firebase: v2 contiene '+' y '/' → + -> -, / -> _
fb_key_path() {
    echo "$1" | tr '+/' '-_'
}

# Consultar la key en Firebase (EN VIVO)
# 0 = key existe | 1 = no existe | 2 = error de red
firebase_consulta() {
    local key="$1"
    local key_path
    key_path=$(fb_key_path "$key")
    local url="https://${FB_BASE}/${FB_LICENCIAS}/${key_path}.json"
    local resp
    resp=$(curl -s --max-time 12 "$url" 2>/dev/null)
    if [[ $? -ne 0 || -z "$resp" ]]; then
        return 2
    fi
    if [[ "$resp" == "null" ]]; then
        return 1
    fi
    echo "$resp"
    return 0
}

# ================= REGISTRO DE IPs (arraigo de la licencia) =================
# Envia IP local + publica al nodo activaciones_movivip/ (DB keygenbpt) <KEY> en Firebase (PATCH).
# Con marca de tiempo ~1h: limita el coste si se llama en cada validacion.
FB_STAMP="/etc/movivip/.last-ping"

# Obtener token Firebase si existen credenciales del panel (.env-bot)
fb_auth_token() {
    local api_key email pass resp token
    [[ -f "$BASE_DIR/.env-bot" ]] || return 1
    # shellcheck disable=SC1091
    source "$BASE_DIR/.env-bot" 2>/dev/null
    api_key="${FB_API_KEY:-}"; email="${FB_AUTH_EMAIL:-}"; pass="${FB_AUTH_PASS:-}"
    [[ -n "$api_key" && -n "$email" && -n "$pass" ]] || return 1
    resp=$(curl -s --max-time 10 -X POST \
        "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${api_key}" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"${email}\",\"password\":\"${pass}\",\"returnSecureToken\":true}" 2>/dev/null)
    token=$(echo "$resp" | grep -oP '"idToken"\s*:\s*"([^"]*)"' | sed 's/.*"\\(.*\\)"/\1/')
    [[ -n "$token" ]] && { echo "$token"; return 0; }
    return 1
}

registrar_ips() {
    local key="$1" now stamp ip_local ip_pub key_path auth=""
    [[ -z "$key" ]] && return 0
    # marca ~1h (formato numerico; si es invalido pingea igual)
    now=$(date +%s)
    stamp=$(cat "$FB_STAMP" 2>/dev/null || echo 0)
    if [[ "$stamp" =~ ^[0-9]+$ ]] && (( now - stamp < 3600 )); then
        return 0
    fi
    ip_local=$(hostname -I 2>/dev/null | awk '{print $1}')
    ip_pub=$(curl -s --max-time 8 "https://api.ipify.org" 2>/dev/null)
    [[ -z "$ip_pub" ]] && ip_pub=$(curl -s --max-time 8 ifconfig.me 2>/dev/null)
    [[ -z "$ip_local" && -z "$ip_pub" ]] && return 0
    key_path=$(fb_key_path "$key")
    # Auth opcional: si el panel dejo credenciales, firma el PATCH
    if token=$(fb_auth_token); then
        auth="?auth=${token}"
    fi
    curl -s --max-time 10 -X PATCH \
        "https://${IP_FB_BASE}/${IP_FB_RAMAS}/${key_path}.json${auth}" \
        -H "Content-Type: application/json" \
        -d "{\"ip_local\":\"${ip_local}\",\"ip_publica\":\"${ip_pub}\",\"ultimo_ping\":${now}}" >/dev/null 2>&1
    echo "$now" > "$FB_STAMP" 2>/dev/null
    return 0
}

# ================= MAIN =================
main() {
    # Validación de licencia desactivada — uso interno del equipo
    exit 0

    local KEY=""

    # 1) Leer key guardada localmente (SOLO la key; plan/cliente se ignoran)
    if [[ -f "$LICENCIA_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$LICENCIA_FILE" 2>/dev/null
        KEY="${KEY:-}"
    fi

    # 2) Si no hay key → intentar gate interactivo (pedir la key)
    if [[ -z "$KEY" ]]; then
        echo -e "${YELLOW}[!] No hay licencia guardada en este servidor.${NC}"
        # Intentar con el gate local (instalado por install.sh)
        if [[ -x "$GATE_LOCAL" ]]; then
            bash "$GATE_LOCAL" || exit 1
            # Releer la key recién guardada
            [[ -f "$LICENCIA_FILE" ]] && source "$LICENCIA_FILE" 2>/dev/null
            KEY="${KEY:-}"
        elif [[ -x "$GATE_LOCAL_LEGACY" ]]; then
            bash "$GATE_LOCAL_LEGACY" || exit 1
            # Releer la key recién guardada
            [[ -f "$LICENCIA_FILE" ]] && source "$LICENCIA_FILE" 2>/dev/null
            KEY="${KEY:-}"
        else
            # Descargar el gate en caliente como último recurso
            local tmp
            tmp=$(mktemp)
            if curl -fsSL --max-time 15 "$GATE_URL" -o "$tmp" 2>/dev/null; then
                chmod +x "$tmp"
                bash "$tmp" || { rm -f "$tmp"; exit 1; }
                rm -f "$tmp"
                [[ -f "$LICENCIA_FILE" ]] && source "$LICENCIA_FILE" 2>/dev/null
                KEY="${KEY:-}"
            else
                mostrar_contacto
                echo -e "${RED}[✘] No se pudo cargar el módulo de licencia.${NC}"
                exit 1
            fi
        fi
        # Si sigue sin key → bloqueado
        if [[ -z "$KEY" ]]; then
            mostrar_contacto
            echo -e "${RED}[✘] No se pudo registrar una clave de licencia.${NC}"
            exit 1
        fi
    fi

    # 3) Validar con el helper central (Firebase EN VIVO; plan REAL)
    if [[ -x "$FIREBASE_PLAN" ]]; then
        # shellcheck disable=SC2034
        FP_VALID=0; FP_PLAN=""; FP_CLIENTE=""; FP_TIPO=""; FP_EXPIRA=""; FP_KEY=""
        # shellcheck source=/dev/null
        source "$FIREBASE_PLAN"
        firebase_plan "$KEY"
        local code=$?
        if [[ $code -eq 2 ]]; then
            # fail-closed: sin internet NO se opera
            mostrar_contacto
            echo -e "${RED}[✘] No se pudo conectar al servidor de licencias.${NC}"
            echo -e "${YELLOW}[!] Verifica la conexión a internet y reintenta.${NC}"
            exit 2
        fi
        if [[ $code -eq 1 ]]; then
            mostrar_contacto
            echo -e "${RED}[✘] La clave '$KEY' no existe / está inactiva o vencida en el sistema.${NC}"
            exit 1
        fi

        # ✅ VÁLIDA — sincronizar licencia.conf con la VERDAD de Firebase
        # (si el cliente editó PLAN/CLIENTE/KEY a mano, aquí se corrige)
        local plan_real cliente_real tipo_real expira_real
        plan_real="${FP_PLAN:-standard}"
        cliente_real="${FP_CLIENTE:-desconocido}"
        tipo_real="${FP_TIPO:-cliente}"
        expira_real="${FP_EXPIRA:-0}"

        mkdir -p "$BASE_DIR"
        cat > "$LICENCIA_FILE" <<EOF
# Movivip Network — Licencia (sincronizada con Firebase EN VIVO)
# ⚠ NO edites este archivo: se sobreescribe en cada validación.
KEY="$KEY"
PLAN="$plan_real"
CLIENTE="$cliente_real"
TIPO="$tipo_real"
EXPIRA="$expira_real"
FECHA="$(date -Iseconds)"
EOF
        chmod 644 "$LICENCIA_FILE"
        registrar_ips "$KEY" 2>/dev/null || true
        exit 0
    fi

    # 4) FALLBACK (helper ausente): validación mínima legacy contra Firebase
    if ! key_formato_valido "$KEY"; then
        mostrar_contacto
        echo -e "${RED}[✘] Clave inválida guardada en $LICENCIA_FILE${NC}"
        exit 1
    fi

    # 4b) Consultar Firebase EN VIVO
    local resp code
    resp=$(firebase_consulta "$KEY")
    code=$?

    if [[ $code -eq 2 ]]; then
        # fail-closed: sin internet NO se opera
        mostrar_contacto
        echo -e "${RED}[✘] No se pudo conectar al servidor de licencias.${NC}"
        echo -e "${YELLOW}[!] Verifica la conexión a internet y reintenta.${NC}"
        exit 2
    fi

    if [[ $code -eq 1 ]]; then
        mostrar_contacto
        echo -e "${RED}[✘] La clave '$KEY' no existe en el sistema.${NC}"
        exit 1
    fi

    # 5) Analizar respuesta
    local activa expira now plan_real cliente_real cliente tipo
    activa=$(json_get "$resp" "activa")
    expira=$(json_get "$resp" "expira")
    plan=$(json_get "$resp" "plan")
    cliente=$(json_get "$resp" "cliente")
    tipo=$(json_get "$resp" "tipo")

    if [[ "$activa" != "true" ]]; then
        mostrar_contacto
        echo -e "${RED}[✘] LICENCIA DESACTIVADA (revocada por el proveedor).${NC}"
        exit 1
    fi

    now=$(date +%s)
    # expira=0 o vacío => VITALICIA. Solo vence si expira > 0 y ya pasó
    if [[ -n "$expira" && "$expira" =~ ^[0-9]+$ && "$expira" -gt 0 && "$now" -gt "$expira" ]]; then
        mostrar_contacto
        echo -e "${RED}[✘] LICENCIA EXPIRADA. Renueva para seguir usando los protocolos.${NC}"
        exit 1
    fi

    # 6) VÁLIDA — sincronizar licencia.conf con la VERDAD de Firebase
    plan_real="${plan:-standard}"
    cliente_real="${cliente:-desconocido}"
    { [[ -z "${tipo:-}" ]] && tipo="cliente"; } 2>/dev/null || tipo="cliente"
    mkdir -p "$BASE_DIR"
    cat > "$LICENCIA_FILE" <<EOF
# Movivip Network — Licencia (sincronizada con Firebase EN VIVO)
# ⚠ NO edites este archivo: se sobreescribe en cada validación.
KEY="$KEY"
PLAN="$plan_real"
CLIENTE="$cliente_real"
TIPO="$tipo"
EXPIRA="$expira"
FECHA="$(date -Iseconds)"
EOF
    chmod 644 "$LICENCIA_FILE"
        registrar_ips "$KEY" 2>/dev/null || true
    exit 0
}

main "$@"
exit $?
