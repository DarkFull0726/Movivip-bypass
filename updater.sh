#!/bin/bash
# Updater desactivado — instalación sin licencia (uso interno)
exit 0

#=========================================================
#   MOVIVIP NETWORK — ACTUALIZADOR PREMIUM v7.0 (RELEASE + SHA256)
#   Actualiza desde la release protegida (sin git clone)
#   Solo funciona con licencia activa
#   ✅ SHA256 verificado antes de ejecutar el instalador
#   💾 El instalador preserva config/licencia/usuarios ZipVPN+Xray
#=========================================================

BASE="/etc/movivip"
CONFIG="$BASE/config.conf"
LICENCIA="$BASE/licencia.conf"
COMMIT_HASH_FILE="$BASE/.last_commit_hash"
RAW_VER="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/version.txt"
REL_URL="https://github.com/studioanime977/MoviVIPNetwork/releases/latest/download"

# Cargar idiomas
if [[ -f "$BASE/languages/lang.sh" ]]; then
    source "$BASE/languages/lang.sh"
    load_language "$(get_current_language)"
fi

RESET="\e[0m"; RED="\e[1;91m"; GREEN="\e[1;92m"; GOLD="\e[1;93m"
BLUE="\e[1;94m"; MAGENTA="\e[1;95m"; CYAN="\e[1;96m"; WHITE="\e[1;97m"; GRAY="\e[1;90m"

W=58
TOP(){ printf "${CYAN}╔"; printf '═%.0s' $(seq 1 $W); printf "╗${RESET}\n"; }
MID(){ printf "${CYAN}╠"; printf '═%.0s' $(seq 1 $W); printf "╣${RESET}\n"; }
BOT(){ printf "${CYAN}╚"; printf '═%.0s' $(seq 1 $W); printf "╝${RESET}\n"; }
ROW(){ printf "${CYAN}║${RESET} %-56s${CYAN}║${RESET}\n" "$1"; }
ROWC(){ printf "${CYAN}║${RESET} %b%*s${CYAN}║${RESET}\n" "$1" $(( 56 - $(echo -ne "$1" | sed 's/\x1b\[[0-9;]*m//g' | wc -c) )) ""; }

SCRIPTS_DIR="/etc/movivip"
BACKUP_DIR="$BASE/backups/$(date +%Y%m%d_%H%M%S)"
TEMP_DIR="/tmp/movivip-update-$$"

#==============================
# [0] VERIFICAR LICENCIA
#==============================

check_license() {
    # Sin archivo de licencia
    if [[ ! -f "$LICENCIA" ]]; then
        return 1
    fi

    source "$LICENCIA" 2>/dev/null

    # Sin key
    [[ -z "$KEY" ]] && return 1

    # LICENCIA_ACTIVA explicitamente false
    [[ "$LICENCIA_ACTIVA" == "false" ]] && return 1

    # Verificar expiración (expira=0 = vitalicia)
    if [[ "$EXPIRA" != "0" && -n "$EXPIRA" ]]; then
        EXPIRA_TS=$(date -d "$EXPIRA" +%s 2>/dev/null || echo 0)
        NOW_TS=$(date +%s)
        if [[ $EXPIRA_TS -gt 0 && $NOW_TS -gt $EXPIRA_TS ]]; then
            return 1
        fi
    fi

    # Validación online contra Firebase (fail-open para updater local)
    FB_BASE="movivip-network-default-rtdb.firebaseio.com"
    FB_PATH="licencias_movivip/$KEY"
    FB_URL="https://${FB_BASE}/${FB_PATH}.json"

    FB_DATA=$(curl -fsSL --max-time 5 "$FB_URL" 2>/dev/null)
    if [[ -n "$FB_DATA" ]]; then
        # Verificar campo activa
        FB_ACTIVA=$(echo "$FB_DATA" | grep -o '"activa":[[:space:]]*true' | head -1)
        [[ -z "$FB_ACTIVA" ]] && return 1

        # Verificar expiración de Firebase
        FB_EXPIRA=$(echo "$FB_DATA" | grep -o '"expira":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        if [[ -n "$FB_EXPIRA" && "$FB_EXPIRA" != "0" ]]; then
            FB_EXPIRA_TS=$(date -d "$FB_EXPIRA" +%s 2>/dev/null || echo 0)
            NOW_TS=$(date +%s)
            [[ $FB_EXPIRA_TS -gt 0 && $NOW_TS -gt $FB_EXPIRA_TS ]] && return 1
        fi
    fi

    return 0
}

clear
TOP
printf "${CYAN}║${RESET}  ${GOLD}🛡️  MoviVIP Network${RESET}  ${WHITE}ACTUALIZADOR v${VERSION:-$(cat "$BASE/version.txt" 2>/dev/null || echo "7.0")}${RESET}${CYAN}             ║${RESET}\n"
printf "${CYAN}║${RESET}  ${GRAY}movivip-network.web.app${RESET}  ${GRAY}·${RESET}  ${WHITE}Release protegida${RESET}${CYAN}                    ║${RESET}\n"
MID
echo ""

# Verificar licencia
if ! check_license; then
    ROWC "${RED}✗ LICENCIA NO VÁLIDA O VENCIDA${RESET}"
    ROWC "${GRAY}El updater requiere licencia activa${RESET}"
    echo ""
    ROWC "${WHITE}Versión actual: ${GOLD}$(cat "$BASE/version.txt" 2>/dev/null || echo '?')${RESET}"
    echo ""
    ROWC "${CYAN}Contacta para adquirir licencia:${RESET}"
    ROW " "
    ROWC "${WHITE}📢 Canal oficial ....... t.me/MoviVIPNetwork${RESET}"
    ROWC "${WHITE}👥 Grupo oficial ........ t.me/MoviVIPNet${RESET}"
    ROWC "${GREEN}💬 Soporte directo ...... @MoviVIP  (t.me/MoviVIP)${RESET}"
    ROWC "${WHITE}🌐 Sitio web ............ https://movivip-network.web.app${RESET}"
    ROWC "${WHITE}📱 WhatsApp ............. +57 311 700 8185${RESET}"
    BOT
    echo ""
    read -rp "$(echo -e "${CYAN}   Enter para volver${RESET}")" _
    [[ -f "$BASE/menu.sh" ]] && exec bash "$BASE/menu.sh" || exit 1
fi

#==============================
# [1] VERIFICAR CONEXIÓN
#==============================

printf "${CYAN}║${RESET} ${GOLD}[1/6]${RESET} Verificando conexión...${CYAN}%*s║${RESET}\n" $(( W - 30 )) ""

if ! curl -fsSL --max-time 5 https://github.com &>/dev/null; then
    ROWC "${RED}✗ Sin conexión a internet${RESET}"
    BOT
    exit 1
fi
ROWC "${GREEN}✓ Conexión establecida${RESET}"

#==============================
# [2] VERIFICAR VERSIÓN
#==============================

printf "${CYAN}║${RESET} ${GOLD}[2/6]${RESET} Verificando versión...${CYAN}%*s║${RESET}\n" $(( W - 27 )) ""

LOCAL_VER=$(tr -d ' \n' < "$BASE/version.txt" 2>/dev/null || echo "0")
REMOTE_VER=$(curl -fsSL --max-time 5 "$RAW_VER" 2>/dev/null | tr -d ' \n')
[[ -z "$REMOTE_VER" ]] && REMOTE_VER=$(curl -fsSL --max-time 8 "https://api.github.com/repos/studioanime977/MoviVIPNetwork/contents/version.txt" 2>/dev/null \
    | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4 | base64 -d 2>/dev/null | tr -d ' \n')

if [[ -z "$REMOTE_VER" ]]; then
    ROWC "${RED}✗ No se pudo verificar versión remota${RESET}"
    BOT
    exit 1
fi

if [[ "$LOCAL_VER" == "$REMOTE_VER" ]]; then
    ROWC "${GREEN}✓ v${LOCAL_VER} — Ya estás actualizado${RESET}"
    BOT
    echo ""
    read -rp "$(echo -e "${CYAN}   Enter para volver${RESET}")" _
    exec bash "$BASE/menu.sh"
fi

ROWC "${WHITE}Local: ${GOLD}v${LOCAL_VER}${RESET}  →  Remota: ${GREEN}v${REMOTE_VER}${RESET}"

#==============================
# [3] RESPALDAR
#==============================

printf "${CYAN}║${RESET} ${GOLD}[3/6]${RESET} Respaldando scripts...${CYAN}%*s║${RESET}\n" $(( W - 27 )) ""

mkdir -p "$BACKUP_DIR"
cp -r "$SCRIPTS_DIR"/* "$BACKUP_DIR/" 2>/dev/null
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')
ROWC "${GREEN}✓ Respaldo (${BACKUP_SIZE:-?})${RESET}"

# Retención: mantener SOLO los 3 respaldos más recientes (evita llenar disco)
ls -1dt "$SCRIPTS_DIR"/backups/*/ 2>/dev/null | tail -n +4 | xargs -r rm -rf 2>/dev/null
BK_KEPT=$(ls -1dt "$SCRIPTS_DIR"/backups/*/ 2>/dev/null | wc -l)
[[ "$BK_KEPT" -gt 0 ]] && ROWC "${GRAY}🧹 Retención de respaldos: ${BK_KEPT}/3${RESET}"

#==============================
# [4] DESCARGAR (RELEASE PROTEGIDA + SHA256)
#==============================

printf "${CYAN}║${RESET} ${GOLD}[4/6]${RESET} Descargando v${GREEN}${REMOTE_VER}${RESET} (release)...${CYAN}%*s║${RESET}\n" $(( W - 30 - ${#REMOTE_VER} )) ""

rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

curl -fL --max-time 180 --retry 3 -o "$TEMP_DIR/install.sh" "$REL_URL/install.sh" 2>/dev/null
if [[ $? -ne 0 ]]; then
    ROWC "${RED}✗ Error descargando install.sh (¿release publicada?)${RESET}"
    ROWC "${GRAY}Restaurando respaldo...${RESET}"
    cp -r "$BACKUP_DIR"/* "$SCRIPTS_DIR/" 2>/dev/null
    BOT
    exit 1
fi

curl -fL --max-time 60 --retry 2 -o "$TEMP_DIR/install.sh.sha256" "$REL_URL/install.sh.sha256" 2>/dev/null
GOT=$(sha256sum "$TEMP_DIR/install.sh" 2>/dev/null | awk '{print $1}')
EXP=$(awk '{print $1}' "$TEMP_DIR/install.sh.sha256" 2>/dev/null)
if [[ -z "$EXP" || "$GOT" != "$EXP" ]]; then
    ROWC "${RED}✗ SHA256 NO COINCIDE — paquete rechazado${RESET}"
    ROWC "${GRAY}obtenido: ${GOT:-?} ${RESET}"
    ROWC "${GRAY}esperado: ${EXP:-?} ${RESET}"
    rm -rf "$TEMP_DIR"
    BOT
    exit 1
fi
ROWC "${GREEN}✓ Descarga + SHA256 verificada (${GOT:0:16}...)${RESET}"

#==============================
# [5] ACTUALIZAR (instalador preserva datos)
#==============================

printf "${CYAN}║${RESET} ${GOLD}[5/6]${RESET} Actualizando...${CYAN}%*s║${RESET}\n" $(( W - 21 )) ""

UPDATED=1
bash "$TEMP_DIR/install.sh" --update
RC=$?
rm -rf "$TEMP_DIR"

if [[ $RC -ne 0 ]]; then
    ROWC "${RED}✗ Instalador reportó error ($RC)${RESET}"
    ROWC "${GRAY}Restaurando respaldo...${RESET}"
    cp -r "$BACKUP_DIR"/* "$SCRIPTS_DIR/" 2>/dev/null
    BOT
    exit 1
fi

# Fix CRLF from Windows — TODOS los .sh del sistema
find "$SCRIPTS_DIR" -name "*.sh" -type f -exec sed -i 's/\r$//' {} + 2>/dev/null
find "$SCRIPTS_DIR/herramientas" -name "*.sh" -type f -exec sed -i 's/\r$//' {} + 2>/dev/null

ROWC "${GREEN}✓ Instalador aplicado (v${REMOTE_VER})${RESET}"

#==============================
# [6] IPTABLES GAMING
#==============================

printf "${CYAN}║${RESET} ${GOLD}[6/6]${RESET} Configurando iptables gaming...${CYAN}%*s║${RESET}\n" $(( W - 33 )) ""

IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
[[ -z "$IFACE" ]] && IFACE=$(ls /sys/class/net 2>/dev/null | grep -E '^(eth|ens|enp)' | head -n1)
IFACE="${IFACE:-eth0}"

DSCP_COUNT=0
for RULE in "7000:7999" "3478:3480" "8000:9000"; do
    if ! iptables -t mangle -C PREROUTING -p udp --dport "$RULE" -j DSCP --set-dscp-class af41 2>/dev/null; then
        iptables -t mangle -A PREROUTING -p udp --dport "$RULE" -j DSCP --set-dscp-class af41
        DSCP_COUNT=$((DSCP_COUNT + 1))
    fi
done

iptables -N MOVIVIP_OUT >/dev/null 2>&1
iptables -C OUTPUT -j MOVIVIP_OUT >/dev/null 2>&1 || iptables -I OUTPUT 1 -j MOVIVIP_OUT

mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

ROWC "${GREEN}✓ iptables configurado${RESET}"

#==============================
# RESUMEN
#==============================

rm -rf "$TEMP_DIR"

echo ""
MID
printf "${CYAN}║${RESET}                                                          ${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}  ${GREEN}✓ ACTUALIZACIÓN COMPLETADA${RESET}                            ${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}                                                          ${CYAN}║${RESET}\n"
printf "${CYAN}║${RESET}  ${GRAY}Versión:${RESET}  ${GOLD}v${LOCAL_VER}${RESET} → ${GREEN}v${REMOTE_VER}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 23 - ${#LOCAL_VER} - ${#REMOTE_VER} )) ""
printf "${CYAN}║${RESET}  ${GRAY}Origen:${RESET}  ${WHITE}GitHub Release (ofuscado)${RESET}${CYAN}%*s║${RESET}\n" $(( W - 25 )) ""
printf "${CYAN}║${RESET}  ${GRAY}Respaldo:${RESET} ${WHITE}${BACKUP_SIZE:-?}${RESET}${CYAN}%*s║${RESET}\n" $(( W - 17 - ${#BACKUP_SIZE} )) ""
printf "${CYAN}║${RESET}                                                          ${CYAN}║${RESET}\n"
MID
printf "${CYAN}║${RESET}  ${GRAY}Restaurar:${RESET} ${WHITE}cp -r ${BACKUP_DIR}/* /etc/movivip/${RESET}${CYAN}%*s║${RESET}\n" $(( W - 8 - ${#BACKUP_DIR} )) ""
printf "${CYAN}║${RESET}                                                          ${CYAN}║${RESET}\n"
BOT

echo ""
read -rp "$(echo -e "${CYAN}   Enter para volver${RESET}")" _
exec bash "$BASE/menu.sh"