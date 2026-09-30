#!/bin/bash
# Updater desactivado — instalación sin licencia (uso interno)
exit 0

# =============================================================================
#  MoviVIP Network — ACTUALIZADOR v7.0 (RELEASE PROTEGIDA + SHA256)
#  ---------------------------------------------------------------------------
#  POLÍTICA DE LICENCIA (confirmada):
#   ✅ NINGÚN plan se desactiva por no pagar la licencia.
#      El panel / los protocolos SIGUEN funcionando normal SIEMPRE.
#   🔒 Solo las ACTUALIZACIONES requieren licencia activa.
#   📢 Si hay actualización disponible y el plan NO está activo:
#      se le NOTIFICA, pero NO se descarga. Renueva para actualizar.
#   ✅ Si el plan está activo: se le notifica y 👑 decide si actualizar o no.
#
#  NUEVO v7.0 — DISTRIBUCIÓN VÍA GITHUB RELEASE (SIN git clone):
#   🔒 El código viaja SOLO en el instalador ofuscado (asset de la release).
#   🛡 El instalador se descarga + verifica SHA256 ANTES de ejecutarlo.
#   💾 El instalador (--update) hace backup + preserva config/licencia/usuarios.
#   ✅ Compatible con v7.x (los VPS v6 debe transicionar una vez manualmente).
#
#  MOTOR DE INTEGRIDAD (heredado):
#   🧹 Repara automaticamente archivos con BOM invisible (causa "command not found")
#   🔍 Detecta errores de sintaxis en todos los .sh y reporta cuales estan rotos
#   🔐 Restaura permisos de ejecucion perdidos
#   📋 Verifica archivos criticos del panel (menus, libs, idiomas)
# =============================================================================

# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi
# ─────────────────────────────────────────────────────────
BASE="/etc/movivip"
LICENCIA="$BASE/licencia.conf"
VERSION_FILE="$BASE/version.txt"
RAW_VER="https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/version.txt"
REL_URL="https://github.com/studioanime977/MoviVIPNetwork/releases/latest/download"
GATE="$BASE/gate/validar-licencia.sh"

RESET="${MV_R:-\e[0m}"; RED="${MV_RED:-\e[1;91m}"; GREEN="${MV_GRN:-\e[1;92m}"; GOLD="${MV_GLD:-\e[1;93m}"; CYAN="${MV_CYN:-\e[1;96m}"; WHITE="${MV_WHT:-\e[1;97m}"; GRAY="${MV_DIM:-\e[1;90m}"

# Versión local instalada
ver_local() {
    if [[ -f "$VERSION_FILE" ]]; then
        tr -d ' \n' < "$VERSION_FILE"
    else
        echo "0.0.0"
    fi
}

# Versión disponible en el repo remoto (vacío = sin conexión/repo sin version.txt)
# ✅ Usa la API de GitHub (sin caché CDN) y fallback a raw/jsDelivr
ver_remota() {
    local V TMP="/tmp/MoviVIP_ver"
    # Prioridad 1: API de GitHub - SIEMPRE fresca, sin cache CDN
    V=$(curl -fsSL --max-time 8 "https://api.github.com/repos/studioanime977/MoviVIPNetwork/contents/version.txt" 2>/dev/null \
        | grep -o '"content":"[^"]*"' | head -1 | cut -d'"' -f4 | base64 -d 2>/dev/null | tr -d ' \n')
    [[ -n "$V" ]] && { echo "$V"; return 0; }
    # Prioridad 2: raw.githubusercontent
    V=$(curl -fsSL --max-time 8 "$RAW_VER" 2>/dev/null | tr -d ' \n')
    [[ -n "$V" ]] && { echo "$V"; return 0; }
    # Prioridad 3: jsDelivr CDN
    V=$(curl -fsSL --max-time 8 "https://cdn.jsdelivr.net/gh/studioanime977/MoviVIPNetwork@main/version.txt" 2>/dev/null | tr -d ' \n')
    echo "$V"
}

hay_actualizacion() {
    local l r
    l=$(ver_local); r=$(ver_remota)
    [[ -z "$r" ]] && return 1
    local l1 l2 l3 r1 r2 r3
    IFS='.' read -r l1 l2 l3 <<< "$l"
    IFS='.' read -r r1 r2 r3 <<< "$r"
    l1=${l1:-0}; l2=${l2:-0}; l3=${l3:-0}
    r1=${r1:-0}; r2=${r2:-0}; r3=${r3:-0}
    if (( r1 > l1 )); then return 0; fi
    if (( r1 == l1 && r2 > l2 )); then return 0; fi
    if (( r1 == l1 && r2 == l2 && r3 > l3 )); then return 0; fi
    return 1
}

licencia_activa() {
    if [[ ! -f "$LICENCIA" ]]; then
        return 2
    fi
    source "$LICENCIA" 2>/dev/null
    local KEY="${KEY:-}"
    [[ -z "$KEY" ]] && return 2

    if [[ -x "$GATE" ]]; then
        LICENCIA_KEY="$KEY" "$GATE" --check >/dev/null 2>&1
        local g=$?
        if [[ $g -eq 0 ]]; then
            return 0
        fi
        if [[ $g -eq 2 ]]; then
            if [[ "${LICENCIA_ACTIVA:-false}" == "true" ]]; then
                local exp="${EXPIRA:-0}"
                if [[ "$exp" =~ ^[0-9]+$ && "$exp" -gt 0 ]]; then
                    [[ "$(date +%s)" -le "$exp" ]] && return 0 || return 1
                fi
                return 0
            fi
        fi
        return 1
    fi

    if [[ "${LICENCIA_ACTIVA:-false}" == "true" ]]; then
        local exp="${EXPIRA:-0}"
        if [[ "$exp" =~ ^[0-9]+$ && "$exp" -gt 0 ]]; then
            [[ "$(date +%s)" -le "$exp" ]] && return 0 || return 1
        fi
        return 0
    fi
    return 1
}

# =============================================================================
# 🧹 MOTOR DE INTEGRIDAD — repara archivos danados SIN reinstalar nada
# =============================================================================
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

verificar_integridad() {
    mkdir -p "$BASE/logs" "$INTEG_DIR"
    local total=0 boms=0 roto=0 perms=0 criticos=0 f
    local detalles=""

    # 1) Escanear todos los .sh legibles (los PACKED son binarios protegidos)
    while IFS= read -r f; do
        head -c 20 "$f" 2>/dev/null | grep -q "MOVIVIP-PACKED" && continue
        total=$((total+1))
        if reparar_bom "$f"; then
            boms=$((boms+1))
            detalles+="  ${GREEN}🧹 Reparado${RESET} BOM invisible: ${GRAY}${f#$BASE/}${RESET}\n"
        fi
        if ! bash -n "$f" >/dev/null 2>&1; then
            roto=$((roto+1))
            detalles+="  ${RED}⚠ ROTO${RESET} sintaxis invalida: ${GRAY}${f#$BASE/}${RESET}\n"
        fi
        if [[ ! -x "$f" ]]; then
            chmod +x "$f"; perms=$((perms+1))
        fi
    done < <(find "$BASE" -maxdepth 3 -name "*.sh" ! -path "$BASE/logs/*" ! -path "$BASE/.pack-backup/*" 2>/dev/null | sort)

    # 2) Archivos criticos que deben existir SIEMPRE
    local crit
    for crit in menu.sh update.sh updater.sh usuarios/menu.sh herramientas/menu.sh protocolos/menu.sh \
                lib/nav.sh lib/ui.sh languages/lang.sh languages/es.sh; do
        if [[ ! -f "$BASE/$crit" ]]; then
            criticos=$((criticos+1))
            detalles+="  ${RED}✗ FALTA${RESET} archivo critico: ${GRAY}$crit${RESET} (actualice para restaurarlo)\n"
        fi
    done

    # 3) Reporte
    echo -e "${CYAN}  ── SALUD DEL SISTEMA ─────────────────────────────${RESET}"
    echo -e "  Scripts revisados : ${WHITE}$total${RESET}   BOM reparados: ${GREEN}$boms${RESET}   Rotos: $([[ $roto -eq 0 ]] && echo -ne "${GREEN}" || echo -ne "${RED}")$roto${RESET}   Permisos fijados: ${GREEN}$perms${RESET}"
    if [[ $criticos -gt 0 ]]; then
        echo -e "  Criticos faltantes: ${RED}$criticos${RESET}"
    fi
    if [[ -n "$detalles" ]]; then
        echo -e "$detalles"
    elif [[ $boms -eq 0 && $roto -eq 0 && $criticos -eq 0 ]]; then
        echo -e "  ${GREEN}  ✅ Todos los archivos estan sanos.${RESET}"
    fi
    echo ""

    rm -rf "$INTEG_DIR"

    # codigo de salida: 0=sano 1=hubo problemas
    [[ $roto -eq 0 && $criticos -eq 0 ]] && return 0
    return 1
}

# =============================================================================
# DESCARGA DE LA RELEASE + VERIFICACIÓN SHA256
#   Devuelve:
#     0 = descargado y verificado → instalador en "$1"
#     1 = error de descarga / conexión
#     2 = SHA256 NO coincide (NUNCA ejecutar)
# =============================================================================
descargar_release() {
    local DEST="$1"
    local GOT EXP
    rm -f "$DEST" "${DEST}.sha256"

    echo -e "${CYAN}  ⬇ Descargando instalador protegido (GitHub Release)...${RESET}"
    curl -fL --max-time 180 --retry 3 -o "$DEST" "$REL_URL/install.sh" 2>/dev/null || {
        echo -e "${RED}  ❌ Error al descargar install.sh de la release.${RESET}"
        echo -e "${GRAY}  (verifica conexión y que la release exista)${RESET}"
        return 1
    }
    curl -fL --max-time 60 --retry 2 -o "${DEST}.sha256" "$REL_URL/install.sh.sha256" 2>/dev/null || {
        echo -e "${RED}  ❌ No se pudo descargar install.sh.sha256.${RESET}"
        return 1
    }

    GOT=$(sha256sum "$DEST" 2>/dev/null | awk '{print $1}')
    EXP=$(awk '{print $1}' "${DEST}.sha256" 2>/dev/null)
    if [[ -z "$EXP" || "$GOT" != "$EXP" ]]; then
        echo -e "${RED}  ❌ VERIFICACIÓN SHA256 NO COINCIDE.${RESET}"
        echo -e "${RED}  Paquete rechazado — NO se ejecutó nada.${RESET}"
        echo -e "${GRAY}    obtenido : ${GOT:-?}${RESET}"
        echo -e "${GRAY}    esperado : ${EXP:-?}${RESET}"
        return 2
    fi
    echo -e "${GREEN}  ✅ SHA256 verificado (${GOT:0:20}...)${RESET}"
    return 0
}

# =============================================================================
# APLICAR LA ACTUALIZACIÓN — release ofuscada + instalador seguro
#   El instalador hace: backup → preserva config/licencia/usuarios → despliega
# =============================================================================
aplicar_update() {
    local INST="/tmp/movivip_release_install_$$.sh"

    descargar_release "$INST" || { rm -f "$INST" "${INST}.sha256"; return 1; }

    echo -e "${GRAY}  ⚙ Instalador verificado. Aplicando actualización...${RESET}"
    bash "$INST" --update
    local RC=$?
    rm -f "$INST" "${INST}.sha256"
    if [[ $RC -ne 0 ]]; then
        echo -e "${RED}  ❌ El instalador reportó un error (código $RC).${RESET}"
        echo -e "${GRAY}  Puedes restaurar con el backup que el instalador dejó en $BASE/backups/${RESET}"
        return 1
    fi

    echo -e "${GREEN}  ✅ Actualizacion completada.${RESET}"
    echo ""
    # Verificacion post-instalacion
    verificar_integridad
    return 0
}

# =============================================================================
# MODOS NO INTERACTIVOS (para cron/monitoreo/pruebas)
#   --integridad : solo escanea y repara, sin preguntar nada
# =============================================================================
MODO="${1:-}"
if [[ "$MODO" == "--integridad" || "$MODO" == "--check" ]]; then
    verificar_integridad
    exit $?
fi

# =============================================================================
# MAIN
# =============================================================================
echo ""
echo -e "${GOLD}  ╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${WHITE}   🔄 MOVIVIP NETWORK — ACTUALIZADOR${RESET}"
echo -e "${GOLD}  ╚══════════════════════════════════════════════════╝${RESET}"
echo ""

LV=$(ver_local)
RV=$(ver_remota)

LIC_STATE=$(licencia_activa; echo $?)
PLAN_LOCAL=""
[[ -f "$LICENCIA" ]] && source "$LICENCIA" && PLAN_LOCAL="${PLAN:-}"

if [[ -z "$RV" ]]; then
    echo -e "${GRAY}  (no se pudo consultar el servidor de actualizaciones)${RESET}"
    echo -e "  Versión local: ${WHITE}v$LV${RESET}"
    verificar_integridad
    echo -e "  ${GRAY}Reintenta más tarde. El panel sigue funcionando normal.${RESET}"
elif ! hay_actualizacion; then
    echo -e "  Versión local : ${WHITE}v$LV${RESET}"
    echo -e "  Versión actual: ${WHITE}v$RV${RESET}"
    echo -e "  ${GREEN}  ✅ Ya tienes la última versión instalada.${RESET}"
    echo ""
    verificar_integridad
    echo -e "  ${GRAY}El panel sigue funcionando normal.${RESET}"
    echo ""
    read -n1 -r -p "$(trx '  Presiona ENTER para volver...')"
    exec "$BASE/menu.sh"
else
    echo -e "  Versión local : ${WHITE}v$LV${RESET}"
    echo -e "  Disponible    : ${GOLD}v$RV${RESET}"
    echo ""
    if [[ "$LIC_STATE" -eq 0 ]]; then
        echo -e "  ${GREEN}  👑 Tu licencia está ACTIVA (plan: ${PLAN_LOCAL:-premium}).${RESET}"
        echo -e "  ${WHITE}  Puedes actualizar cuando quieras.${RESET}"
        echo ""
        read -rp "$(echo -e "${CYAN}  ¿Deseas actualizar ahora? [s/N] › ${RESET}")" CONFIRMA
        case "${CONFIRMA,,}" in
            s|si|sí|y|yes)
                aplicar_update
                echo ""
                read -n1 -r -p "$(trx '  Presiona ENTER para continuar...')"
                exec "$BASE/menu.sh"
            ;;
            *)
                echo -e "  ${GOLD}  ⏭ Omitido. Puedes actualizar luego desde el menú 🛠 [09] Update.${RESET}"
                echo -e "  ${GRAY}  El panel sigue funcionando normal.${RESET}"
                echo ""
                read -n1 -r -p "$(trx '  Presiona ENTER para volver...')"
                exec "$BASE/menu.sh"
            ;;
        esac
    else
        echo -e "  ${GOLD}  📢 HAY UNA ACTUALIZACIÓN DISPONIBLE (v$RV)${RESET}"
        echo ""
        if [[ "$LIC_STATE" -eq 2 ]]; then
            echo -e "  ${RED}  ⚠ Tu servidor no tiene una licencia activa.${RESET}"
        else
            echo -e "  ${RED}  ⚠ Tu plan (${PLAN_LOCAL:-standard}) no está activo.${RESET}"
        fi
        echo ""
        echo -e "$(trx '  ✅ Tu panel y protocolos SIGUEN FUNCIONANDO NORMAL.')"
        echo -e "$(trx '  🔒 Las actualizaciones requieren licencia activa.')"
        echo -e "$(trx '  💡 Renueva tu licencia para recibir esta y futuras actualizaciones.')"
        echo ""
        echo -e "  ${CYAN}  👑 Contáctanos para renovar:${RESET}"
        echo -e "  ──────────────────────────────────────────────"
        echo -e "  ${WHITE}  💬 Telegram : @MoviVIP${RESET}"
        echo -e "  ${WHITE}  📱 WhatsApp : +57 311 700 8185${RESET}"
        echo -e "  ${WHITE}  🌐 Web      : https://movivip-network.web.app${RESET}"
        echo -e "  ${WHITE}  📢 Canal    : https://t.me/MoviVIPNetwork${RESET}"
        echo -e "  ${WHITE}  👥 Grupo    : https://t.me/MoviVIPNet${RESET}"
        echo -e "  ──────────────────────────────────────────────"
        echo ""
        read -n1 -r -p "$(trx '  Presiona ENTER para volver...')"
        exec "$BASE/menu.sh"
    fi
fi