#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# AUTO-REPAIR: Detectar instalación incompleta y limpiar
# Si /etc/movivip existe pero falta archivos críticos, es una
# instalación fallida anterior → limpiar todo para reinstalar.
# Solo delegar al updater si la instalación está COMPLETA.
# ═══════════════════════════════════════════════════════════════
# ── i18n shim (auto) ───────────────────────────────
if ! declare -F trx >/dev/null 2>&1; then trx() { printf '%s' "$1"; }; fi

# ── Separador NEBULA adaptativo (móvil 30..46 cols) — FIX v6.3 ──
mv_hr(){
    local _w
    _w=$(tput cols 2>/dev/null || echo 46)
    [[ "$_w" =~ ^[0-9]+$ ]] || _w=46
    (( _w < 30 )) && _w=30
    (( _w > 46 )) && _w=46
    printf '━%.0s' $(seq 1 $_w); echo
}

# ── PRESERVAR/RESTAURAR USUARIOS ZipVPN + Xray (DEFINIDAS AQUÍ PARA limpiar_disco_profundo) ──
PRESERVED_DIR="/tmp/movivip-preserve"
mkdir -p "$PRESERVED_DIR" 2>/dev/null

preservar_usuarios_vpn() {
    # ZipVPN: guardar config completo si existe (contiene los passwords)
    if [[ -f /etc/zivpn/config.json ]]; then
        cp -f /etc/zivpn/config.json "$PRESERVED_DIR/zivpn-config.json" 2>/dev/null
    fi
    # Xray: guardar config completo si existe (contiene clients vmess/vless/trojan)
    if [[ -f /usr/local/etc/xray/config.json ]]; then
        cp -f /usr/local/etc/xray/config.json "$PRESERVED_DIR/xray-config.json" 2>/dev/null
    fi
}

restaurar_usuarios_vpn() {
    # ZipVPN: restaurar SOLO si el nuevo config no tiene passwords reales
    if [[ -f "$PRESERVED_DIR/zivpn-config.json" ]]; then
        local _now
        _now=$(jq -r '[.auth.config[]?] | length' /etc/zivpn/config.json 2>/dev/null || echo 0)
        local _saved
        _saved=$(jq -r '[.auth.config[]?] | length' "$PRESERVED_DIR/zivpn-config.json" 2>/dev/null || echo 0)
        if [[ "$_now" -le 1 && "$_saved" -gt 1 ]]; then
            cp -f "$PRESERVED_DIR/zivpn-config.json" /etc/zivpn/config.json 2>/dev/null
            chmod 600 /etc/zivpn/config.json 2>/dev/null
            echo -e "      ${GREEN}✔ ${WHITE}ZipVPN: ${GREEN}$_saved${WHITE} passwords preservados y restaurados${RESET}"
        fi
    fi
    # Xray: restaurar SOLO si el nuevo config no tiene clients
    if [[ -f "$PRESERVED_DIR/xray-config.json" ]]; then
        local _nowx
        _nowx=$(jq -r '[.inbounds[].settings.clients[]?] | length' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
        local _savedx
        _savedx=$(jq -r '[.inbounds[].settings.clients[]?] | length' "$PRESERVED_DIR/xray-config.json" 2>/dev/null || echo 0)
        if [[ "$_nowx" -eq 0 && "$_savedx" -gt 0 ]]; then
            cp -f "$PRESERVED_DIR/xray-config.json" /usr/local/etc/xray/config.json 2>/dev/null
            chmod 644 /usr/local/etc/xray/config.json 2>/dev/null
            echo -e "      ${GREEN}✔ ${WHITE}Xray/V2Ray: ${GREEN}$_savedx${WHITE} usuarios preservados y restaurados${RESET}"
        fi
    fi
    rm -rf "$PRESERVED_DIR" 2>/dev/null
}

# ── FUNCIÓN: limpiar_disco_profundo (DEFINIDA AQUÍ PARA --limpiar-solo) ──
limpiar_disco_profundo() {
    echo ""
    echo "🧹 FORMATEO TOTAL — Limpieza de TODAS las scripts previas..."
    echo "   Conservando SO + SSH + master key + tooling + BD usuarios"
    echo ""

    # ── 0) Detener TODOS los servicios de scripts previas ─────────
    echo "   [0/10] Deteniendo servicios de scripts previas..."
    for _svc in apiAccess apiAccess.service telegram telegram.service \
                xray xray.service v2ray v2ray.service \
                dropbear dropbear.service dropbear_custom dropbear-custom \
                badvpn-udpgw badvpn-udpgw-7300 badvpn-udpgw-7200 badvpn \
                udp-custom udpcustom udp zivpn zivpn.service slowdns slowdns.service \
                dnstt stunnel4 stunnel haproxy haproxy.service \
                sshws ssh-websocket ssl-tunnel ssl-tunnel.service \
                openvpn squid webmin mvv-relay mvv-relay.service \
                hcr hcr.service \
                movivip-licgate movivip-ddos movivip-bot-generador \
                movivip-cliente-admin movivip-cliente-notif movivip-boot-network \
                movivip-net-state netvip adm admrufu vpsmx; do
        systemctl stop "$_svc" 2>/dev/null
        systemctl disable "$_svc" 2>/dev/null
    done
    killall -9 xray v2ray dropbear badvpn-udpgw badvpn stunnel haproxy 2>/dev/null || true

    # ── 1) Unidades systemd de scripts previas ────────────────────
    echo "   [1/10] Eliminando unidades systemd de scripts previas..."
    rm -f /etc/systemd/system/apiAccess.service /etc/systemd/system/telegram.service
    rm -f /etc/systemd/system/mvv-relay.service /etc/systemd/system/movivip-*.service
    rm -f /etc/systemd/system/xray*.service /etc/systemd/system/v2ray*.service
    rm -f /etc/systemd/system/dropbear*.service /etc/systemd/system/badvpn*.service
    rm -f /etc/systemd/system/udpcustom*.service /etc/systemd/system/udp-custom*.service
    rm -f /etc/systemd/system/slowdns*.service /etc/systemd/system/zivpn*.service
    rm -f /etc/systemd/system/dnstt*.service /etc/systemd/system/stunnel*.service
    rm -f /etc/systemd/system/sshws*.service /etc/systemd/system/ssl-tunnel*.service
    rm -f /etc/systemd/system/netvip*.service /etc/systemd/system/adm*.service
    rm -f /etc/systemd/system/movivip*.service /etc/systemd/system/mvv*.service
    rm -f /etc/systemd/system/vpsmx*.service
    # Timers + drop-ins (.d) de scripts previas
    rm -f /etc/systemd/system/movivip*.timer /etc/systemd/system/*vpn*.timer 2>/dev/null
    rm -rf /etc/systemd/system/movivip*.service.d /etc/systemd/system/xray*.service.d \
           /etc/systemd/system/v2ray*.service.d /etc/systemd/system/dropbear*.service.d \
           /etc/systemd/system/badvpn*.service.d /etc/systemd/system/udp*.service.d \
           /etc/systemd/system/slowdns*.service.d /etc/systemd/system/zivpn*.service.d \
           /etc/systemd/system/mvv*.service.d /etc/systemd/system/apiAccess.service.d \
           /etc/systemd/system/telegram.service.d /etc/systemd/system/netvip*.service.d 2>/dev/null
    # Barrido final robusto: cualquier unidad/drop-in/timer de scripts previas
    find /etc/systemd/system -maxdepth 1 -type d -name '*.service.d' 2>/dev/null | \
        grep -iE 'movivip|xray|v2ray|dropbear|badvpn|udp|slowdns|zivpn|stunnel|mvv|netvip|apiaccess|telegram|adm' | \
        while read -r _d; do rm -rf "$_d" 2>/dev/null; done
    systemctl daemon-reload 2>/dev/null

    # ── 2) Restos de licencia y scripts ADMRufu/ADM ──────────────
    echo "   [2/10] Restos de licencias y scripts ADMRufu/ADM..."
    rm -f /etc/ADMRufuLIC /etc/ADMRufuLIC.bak-* /etc/ADMLIC /etc/ADMLIC.bak-* 2>/dev/null
    rm -rf /root/ADMRufu /root/ADMRufu.bak /root/ADMrufu /root/admrufu /root/adm /root/ADM 2>/dev/null

    # ── 3) Dirs y archivos de scripts previas en /root ────────────
    echo "   [3/10] Limpiando /root (scripts previas)..."
    for _d in /root/*; do
        [[ -e "$_d" ]] || continue
        case "$(basename "$_d")" in
            .ssh|.nvm|.npm|go|snap|movivip.db|.bashrc|.profile|.config|.bash_history|.wget-hsts|.master_key.b64|connect_relay.py)
                continue ;;
        esac
        rm -rf "$_d" 2>/dev/null
    done
    rm -f /root/*.zip /root/*.tar.gz /root/*.sh /root/*.ps1 /root/*.py 2>/dev/null

    # ── 4) Dirs de configuración de scripts previas ───────────────
    echo "   [4/10] Configs de scripts previas (/etc, /usr/local)..."
    # Preservar usuarios ZipVPN + Xray antes de limpiar (FIX v6.5)
    preservar_usuarios_vpn
    rm -rf /etc/movivip /etc/xray /usr/local/etc/xray /etc/v2ray 2>/dev/null
    rm -rf /etc/slowdns /etc/zivpn /etc/netvip /etc/adm /etc/admrufu 2>/dev/null
    rm -rf /usr/local/SlowDNS /usr/local/etc/v2ray /usr/local/etc/stunnel 2>/dev/null
    rm -rf /etc/stunnel /etc/haproxy /etc/sshws /etc/ssl-tunnel 2>/dev/null
    rm -f /etc/profile.d/MoviVIP-banner.sh /etc/profile.d/admrufu*.sh /etc/issue.net 2>/dev/null
    rm -f /etc/sysctl.d/99-z-MoviVIP.conf /etc/sysctl.d/99-movivip.conf 2>/dev/null

    # ── 5) Bins de scripts previas (NO toca bins de apt) ──────────
    echo "   [5/10] Bins manuales de scripts previas..."
    rm -f /usr/local/bin/xray /usr/bin/xray /usr/local/bin/v2ray /usr/bin/v2ray 2>/dev/null
    rm -f /usr/local/bin/dropbear /usr/bin/dropbear /usr/sbin/dropbear 2>/dev/null
    rm -f /usr/bin/badvpn-udpgw /usr/local/bin/badvpn-udpgw /usr/bin/udp /usr/bin/config.json 2>/dev/null
    rm -f /usr/local/bin/dnstt /usr/local/bin/sshws /usr/local/bin/stunnel /usr/local/bin/haproxy 2>/dev/null
    rm -f /usr/local/bin/netvip /usr/local/bin/adm /usr/local/bin/vpsmx /usr/local/bin/menu.sh 2>/dev/null
    # ── 6) Certificados/keys de scripts previas ────────────────────
    echo "   [6/10] Certificados de scripts previas (no los de apt)..."
    rm -rf /etc/xray /etc/v2ray /etc/stunnel /etc/letsencrypt/live/*vpn* 2>/dev/null
    rm -f /root/*.crt /root/*.key /root/*.pem 2>/dev/null

    # ── 7) Paquetes huérfanos + caché apt ─────────────────────────
    echo "   [7/10] Caché de paquetes (apt/dnf/zypper)..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get clean 2>/dev/null
        apt-get autoremove -y 2>/dev/null
    elif command -v dnf >/dev/null 2>&1; then
        dnf clean all 2>/dev/null; dnf autoremove -y 2>/dev/null
    elif command -v zypper >/dev/null 2>&1; then
        zypper clean 2>/dev/null
    fi

    # ── 8) Journals, logs rotados, cachés, temporales ──────────────
    echo "   [8/10] Journals/logs/cachés/temporales..."
    command -v journalctl >/dev/null 2>&1 && journalctl --vacuum-size=50M 2>/dev/null
    find /var/log -type f \( -name '*.gz' -o -name '*.old' -o -name '*.1' \) -delete 2>/dev/null
    find /var/log -type f -size +20M -exec truncate -s 0 {} + 2>/dev/null
    rm -rf /root/.cache/* /root/.local/tmp/* 2>/dev/null
    rm -rf /root/.npm/_cacache 2>/dev/null
    rm -rf /tmp/* /var/tmp/* 2>/dev/null

    # ── 9) Snaps (solo si existen) ────────────────────────────────
    echo "   [9/10] Snapd (si existe)..."
    if command -v snap >/dev/null 2>&1; then
        snap remove --purge lxd 2>/dev/null; snap remove --purge core20 2>/dev/null
        snap remove --purge core22 2>/dev/null; snap remove --purge core22 2>/dev/null
        snap remove --purge snapd 2>/dev/null
        rm -rf /snap /var/snap /var/lib/snapd 2>/dev/null
        systemctl stop snapd.service snapd.socket snapd.seeded.service 2>/dev/null
        systemctl disable snapd.service snapd.socket snapd.seeded.service 2>/dev/null
    fi

    # ── 10) iptables limpio + crons de scripts previas ────────────
    echo "   [10/10] iptables + crons de scripts previas..."
    iptables -F 2>/dev/null; iptables -X 2>/dev/null
    iptables -t nat -F 2>/dev/null; iptables -t nat -X 2>/dev/null
    iptables -t mangle -F 2>/dev/null; iptables -t mangle -X 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null; iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables -I INPUT 1 -p tcp --dport 22 -j ACCEPT 2>/dev/null
    iptables -I INPUT 2 -p tcp --dport 54321 -j ACCEPT 2>/dev/null
    iptables -I INPUT 3 -p tcp --dport 8012 -j ACCEPT 2>/dev/null
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    crontab -l 2>/dev/null | grep -Ev "ADMRufu|/root/bin|/root/menu\.sh|/etc/movivip|xray|v2ray|slowdns|udp" | crontab - 2>/dev/null

    echo ""
    echo "   ✔ Disco formateado (scripts) — listo para instalación fresca."
    echo ""
    df -h / 2>/dev/null | tail -1
}

# ── ARGUMENTOS: --limpiar / --limpiar-solo (DEBE IR ANTES DE AUTO-REPAIR) ──
if [[ "${1:-}" == "--limpiar" || "${1:-}" == "--format" || "${1:-}" == "-limpiar"
   || "${1:-}" == "--limpiar-solo" || "${1:-}" == "--format-solo" ]]; then
    limpiar_disco_profundo
    if [[ "${1:-}" == "--limpiar-solo" || "${1:-}" == "--format-solo" ]]; then
        exit 0
    fi
fi

# ─────────────────────────────────────────────────────────
if [[ -d "/etc/movivip" ]]; then
    # Verificar si la instalación está completa (archivos críticos)
    _NEEDS_REPAIR=0
    for _crit in menu.sh config.conf protocolos usuarios; do
        if [[ ! -e "/etc/movivip/$_crit" ]]; then
            _NEEDS_REPAIR=1
            break
        fi
    done

    # FIX v7.3.3: UNA KEY POR CLI YA NO FUERZA LIMPIEZA TOTAL.
    #   v7.0.1 ordenaba _NEEDS_REPAIR=1 con cualquier key → el instalador
    #   DESINSTALABA xray (rm -rf /usr/local/etc/xray, borraba binarios y
    #   servicios) y el usuario perdía TODOS los clientes VPN. Ciclo: key →
    #   desinstala → reinstala → crea usuario → check-limits lo borra.
    #   AHORA: si la instalación está COMPLETA, una key por CLI se trata como
    #   ACTUALIZACIÓN NO DESTRUCTIVA (delegada a update.sh, que baja la última
    #   release y preserva config, licencia, usuarios y clientes VPN).
    #   Solo se repara/limpia si faltan archivos críticos (bucle _crit de arriba).

    if [[ "$_NEEDS_REPAIR" -eq 1 ]]; then
        echo ""
        echo "$(trx '⚠️  Instalación incompleta o con key de licencia — preparando instalación...')"
        echo "$(trx '   → Limpiando automáticamente para reinstalación...')"
        echo ""
        # Detener servicios VPN/Proxy sueltos
        for _svc in xray v2ray dropbear dropbear_custom badvpn-udpgw-7300 badvpn-udpgw-7200 \
                     udp-custom zivpn slowdns squid webmin openvpn hcr; do
            systemctl stop "$_svc" 2>/dev/null
            systemctl disable "$_svc" 2>/dev/null
        done
        killall -9 xray v2ray dropbear badvpn-udpgw hcr 2>/dev/null || true
        # Preservar usuarios ZipVPN + Xray antes de limpiar (FIX v6.5)
        preservar_usuarios_vpn
        # Limpiar configuraciones de servicios
        rm -rf /etc/xray /usr/local/etc/xray /etc/v2ray
        rm -f /usr/bin/xray /usr/local/bin/xray /usr/bin/dropbear /usr/sbin/dropbear
        rm -f /usr/bin/badvpn-udpgw /usr/bin/udp /usr/bin/config.json
        rm -rf /usr/local/SlowDNS /tmp/dnstt* /etc/slowdns /etc/zivpn
        rm -f /etc/systemd/system/xray*.service /etc/systemd/system/v2ray*.service
        rm -f /etc/systemd/system/dropbear*.service /etc/systemd/system/badvpn*.service
        rm -f /etc/systemd/system/udpcustom*.service /etc/systemd/system/slowdns*.service
        rm -f /etc/systemd/system/zivpn*.service /etc/systemd/system/movivip*.service
        # Limpiar config de red
        rm -f /etc/sysctl.d/99-z-MoviVIP.conf /etc/sysctl.d/99-movivip.conf
        # Limpiar crons
        crontab -l 2>/dev/null | grep -v "movivip\|auto-cleanup\|auto-update\|network_snapshot\|online.sh" | crontab - 2>/dev/null
        # Reset iptables a ACCEPT (sin DROP) para que SSH no se cierre
        iptables -F 2>/dev/null
        iptables -X 2>/dev/null
        iptables -t nat -F 2>/dev/null
        iptables -t nat -X 2>/dev/null
        iptables -t mangle -F 2>/dev/null
        iptables -t mangle -X 2>/dev/null
        iptables -P INPUT ACCEPT 2>/dev/null
        iptables -P FORWARD ACCEPT 2>/dev/null
        iptables -P OUTPUT ACCEPT 2>/dev/null
        # Eliminar directorio incompleto
        rm -rf /etc/movivip
        rm -f /etc/profile.d/MoviVIP-banner.sh /etc/issue.net
        # ABRIR PUERTOS DE EMERGENCIA SIEMPRE (22 + 54321 + 8012)
        iptables -I INPUT 1 -p tcp --dport 22 -j ACCEPT
        iptables -I INPUT 2 -p tcp --dport 54321 -j ACCEPT
        iptables -I INPUT 3 -p tcp --dport 8012 -j ACCEPT
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        systemctl daemon-reload 2>/dev/null
        # Preservar key si existe
        [[ -f /tmp/movivip-key.txt ]] && cp /tmp/movivip-key.txt /tmp/movivip-key-backup.txt
        echo "$(trx '✔ Sistema limpiado — continuando instalación fresca...')"
        echo ""
    else
        # Instalación completa sin key por CLI → actualización de un sistema existente
        echo "$(trx ' Actualización detectada...')"
        echo " (re-desplegando árbol del payload sobre /etc/movivip...)"
        # v7.4.1 FIX: antes delegábamos SOLO en update.sh (que no hace nada si
        # local == remota) y los archivos nuevos quedaban en el SRC (user/)
        # sin copiarse nunca a la ruta real. Ahora re-desplegamos el árbol
        # local del payload (ya extraído por el stub) preservando el estado.
        _up_src=""
        if [[ -n "${MOVIVIP_SRC:-}" && -f "$MOVIVIP_SRC/menu.sh" && -d "$MOVIVIP_SRC/protocolos" ]]; then
            _up_src="$MOVIVIP_SRC"
        elif [[ -f /usr/local/movivip-src/menu.sh && -d /usr/local/movivip-src/protocolos ]]; then
            _up_src="/usr/local/movivip-src"
        elif [[ -f "$(dirname "$0")/menu.sh" && -d "$(dirname "$0")/protocolos" ]]; then
            # v8.0 FIX: el stub hace `cd <payload> && exec ./install.sh`, así que
            # el propio directorio del instalador ES el payload. Antes solo mirábamos
            # MOVIVIP_SRC (nunca exportado por el stub) y /usr/local/movivip-src
            # (ausente en instalaciones existentes) → el update no desplegaba nada.
            _up_src="$(cd "$(dirname "$0")" && pwd)"
        fi
        if [[ -n "$_up_src" ]]; then
            _up_bak="/tmp/mv-up-bak-$$"
            mkdir -p "$_up_bak"
            # Preservar estado local (.conf/.db/licencia.conf) antes de pisar
            find /etc/movivip -maxdepth 3 -type f \( -name '*.conf' -o -name '*.db' -o -name 'licencia.conf' \) -exec cp -a --parents {} "$_up_bak/" \; 2>/dev/null || true
            cp -a "$_up_src"/. /etc/movivip/ 2>/dev/null || true
            chmod -R +x /etc/movivip 2>/dev/null || true
            # Restaurar estado local preservado
            while IFS= read -r _f; do
                [[ -z "$_f" ]] && continue
                _rel="${_f#$_up_bak/}"
                cp -a "$_f" "/etc/movivip/$_rel" 2>/dev/null || true
            done < <(find "$_up_bak" -type f 2>/dev/null)
            rm -rf "$_up_bak"
            # v7.4.1: registrar la versión del instalador público si la exportó
            if [[ -n "${MOVIVIP_VERSION:-}" ]]; then
                printf '%s\n' "$MOVIVIP_VERSION" > /etc/movivip/version.txt
                echo " ✅ Versión registrada: ${MOVIVIP_VERSION}"
            fi
            echo " ✅ Scripts actualizados en /etc/movivip (ruta real)."
            # v8.0: registrar cron del verificador de expiración exacta (minuto)
            chmod +x /etc/movivip/scripts/expira-exacta.sh 2>/dev/null || true
            ( crontab -l 2>/dev/null | grep -v 'expira-exacta'; echo '* * * * * bash /etc/movivip/scripts/expira-exacta.sh >/dev/null 2>&1' ) | crontab - 2>/dev/null || true
            echo " ✅ Cron expira-exacta (minuto) configurado."
            # v8.2.1 FIX: tras re-desplegar el árbol, recrear SIEMPRE los launchers
            # seguros (menu/protocolos/herramientas/usuarios) y el banner 3D de marca.
            # Motivo: instalaciones viejas (7.4.5) no dejan /usr/local/bin/usuarios ni
            # el /etc/issue.net 3D; el update era el único canal para corregirlas.
            mkdir -p /usr/local/bin
            _LAUNCH_OK=0
            for _L in menu protocolos herramientas usuarios; do
                if [[ -f "/etc/movivip/launchers/$_L" ]]; then
                    cp -f "/etc/movivip/launchers/$_L" "/usr/local/bin/$_L" 2>/dev/null && chmod +x "/usr/local/bin/$_L" && _LAUNCH_OK=1
                fi
            done
            if [[ ! -x /usr/local/bin/menu && -f /etc/movivip/lib/launch.sh ]]; then
                printf '#!/bin/bash\nexec bash /etc/movivip/lib/launch.sh /etc/movivip/menu.sh "$@"\n' > /usr/local/bin/menu
                chmod +x /usr/local/bin/menu
            fi
            [[ "$_LAUNCH_OK" -eq 1 ]] && echo " ✅ Launchers recreados (menu/protocolos/herramientas/usuarios)."
            # v8.2.16 FIX: el issue_net_3d.html ya trae el sello 🛡 SISTEMA PROTEGIDO 🛡
            # DENTRO del HTML (antes de </html>). NUNCA anexar texto plano fuera.
            if [[ -f /etc/movivip/lib/banners/issue_net_3d.html ]]; then
                cp -f /etc/movivip/lib/banners/issue_net_3d.html /etc/issue.net
                echo " ✅ Banner 3D de marca restaurado en /etc/issue.net."
            fi
        else
            echo " (sin payload local disponible — delegando en update.sh remoto)"
            bash <(curl -fsSL https://raw.githubusercontent.com/studioanime977/MoviVIPNetwork/main/update.sh) || true
        fi
        exit 0
    fi
fi
# ═══════════════════════════════════════════════════════════════
# FORMATEO TOTAL DE SCRIPTS (modo formateo)
# Uso: bash install.sh --limpiar      (limpia + continúa instalación)
#      bash install.sh --limpiar-solo (solo limpia, sale)
# Elimina CUALQUIER script instalada antes (ADMRufu, ADM, MoviVIP viejo,
# NetVip, xray/v2ray/dropbear/badvpn manuales, etc.) SIN tocar el SO:
#   ✔ Conserva (NO SE TOCAN):
#     - Sistema operativo: /usr (paquetes apt), /etc (configs SO: ssh,
#       network, passwd, shadow, group, sysctl, apt), /boot, kernel, /lib
#     - Acceso: /root/.ssh, /root/.bashrc, /root/.profile, /root/.config
#     - Negocio: /root/.master_key.b64 (master key — SIN ella no validan
#       las keys v2 ya emitidas)
#     - Tooling usuario: /root/.nvm, /root/.npm, /root/go
#     - Datos: /root/movivip.db (BD usuarios — respaldo disponible)
#   ⚠ Borra (formato total de scripts previas):
#     - Dirs/archivos de scripts en /root (ADMRufu, scrip*, movivip*,
#       bin, protocolos, lib, menu*, update*, instaladores, zips, etc.)
#     - Servicios systemd de scripts previas (apiAccess, telegram, xray,
#       v2ray, dropbear, badvpn, udp-custom, zivpn, slowdns, stunnel,
#       sshws, movivip-*, mvv-*, netvip*, adm*, etc.)
#     - Bins de scripts en /usr/bin y /usr/local/bin (xray, v2ray, ...)
#     - Configs de scripts: /etc/xray, /etc/v2ray, /etc/slowdns, etc.
#     - Certificados/dominios de scripts previas (NO los de apt/systemd)
#     - Cachés, logs rotados, journals viejos, snaps, /tmp
#     - Crons que apunten a scripts borradas
# Ejecuta en TODA instalación fresca (automático) para dejar disco limpio.
# ═══════════════════════════════════════════════════════════════
# COLOR SYSTEM (before language loads)
# ════════════════════════════════════════════════════════════════
CYAN="\e[1;96m"; GOLD="\e[1;93m"; GREEN="\e[1;92m"; RED="\e[1;91m"
WHITE="\e[1;97m"; GRAY="\e[1;90m"; MAGENTA="\e[1;95m"; RESET="\e[0m"

# ═══════════════════════════════════════════════════════════════
# SISTEMA DE PROGRESO + ERROR REPORTING
# Logs completos en /var/log/movivip-install.log para soporte
# ═══════════════════════════════════════════════════════════════

INSTALL_LOG="/var/log/movivip-install.log"
INSTALL_STEP=0
INSTALL_TOTAL=19

log_error() {
    local line="$1" desc="$2" cmd="$3" err="$4"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR Línea $line: $desc | Comando: $cmd | Error: $err" >> "$INSTALL_LOG"
}

show_progress_bar() {
    local current="$1"
    local total="$2"
    local desc="$3"
    local width=40
    local pct=0
    [[ "$total" -gt 0 ]] && pct=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))

    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    local color="$CYAN"
    if [[ "$pct" -ge 80 ]]; then color="$GREEN"
    elif [[ "$pct" -ge 50 ]]; then color="$GOLD"
    fi

    printf "\r${CYAN}   [${color}%s${CYAN}]${WHITE} %3d%%${GRAY} [%d/%d]${WHITE} %-45s${RESET}" \
        "$bar" "$pct" "$current" "$total" "$desc"
}

# ── ANIMACIÓN DE CARGA ────────────────────────────────────────
# Dibuja una barra parcial EN VIVO sobre la misma línea (\r).
# Se llama repetidamente mientras un proceso corre en background.
_anim_bar() {
    local pct="$1" label="$2"
    local width=30
    local filled=$(( width * pct / 100 ))
    [[ $filled -gt $width ]] && filled=$width
    local bar="" i
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=filled; i<width; i++)); do bar+="░"; done
    printf "\r      ${CYAN}[${GOLD}%s${CYAN}]${WHITE} %3d%%${GRAY} %-40s${RESET}" \
        "$bar" "$pct" "${label:0:38}"
}

step() {
    INSTALL_STEP=$((INSTALL_STEP + 1))
    local desc="$1"
    echo ""
    # Barra de sección que se llena ANIMADAMENTE hasta su posición real
    local target=$(( INSTALL_STEP * 100 / INSTALL_TOTAL ))
    local p=0
    while [[ $p -lt $target ]]; do
        p=$(( p + 7 ))
        [[ $p -gt $target ]] && p=$target
        _anim_bar "$p" "PASO $INSTALL_STEP/$INSTALL_TOTAL · $desc"
        sleep 0.04
    done
    printf "\n"
}

run_cmd() {
    local desc="$1" line="$2"
    shift 2
    local cmd_str="$*"
    local tmp_err
    tmp_err=$(mktemp)
    # El comando corre en BACKGROUND y la barra se anima en vivo
    eval "$cmd_str" </dev/null >/dev/null 2>"$tmp_err" &
    local pid=$!
    local pct=0
    while kill -0 "$pid" 2>/dev/null; do
        pct=$(( pct + 3 ))
        [[ $pct -gt 92 ]] && pct=92
        _anim_bar "$pct" "$desc ..."
        sleep 0.13
    done
    wait "$pid"
    local rc=$?
    local err_msg
    err_msg=$(tail -1 "$tmp_err" 2>/dev/null | cut -c1-120)
    rm -f "$tmp_err"
    if [[ $rc -eq 0 ]]; then
        printf "\r\033[K      ${GREEN}✔${RESET} %-52s${GREEN}[OK]${RESET}\n" "${desc:0:48}"
    else
        printf "\r\033[K      ${RED}✖${RESET} %-52s${RED}[ERROR]${RESET}\n" "${desc:0:48}"
        echo -e "      ${GRAY}  → Reportar a soporte: Línea $line${RESET}"
        log_error "$line" "$desc" "$cmd_str" "$err_msg"
    fi
}

clear
echo -e "${CYAN}$(mv_hr)${RESET}"
echo -e "${GOLD}      🛡️ MoviVIP Network — INSTALADOR v6.0 🛡️${RESET}"
echo -e "${CYAN}$(mv_hr)${RESET}"
echo ""

export DEBIAN_FRONTEND=noninteractive

if [[ $EUID -ne 0 ]]; then
echo -e "${RED}❌ Necesita root${RESET}"
exec sudo bash "$0" "$@"
fi

source /etc/os-release

# ═══════════════════════════════════════════════════════════════
# SOPORTE MULTI-DISTRO
# ═══════════════════════════════════════════════════════════════

DISTRO_OK=0
case "$ID" in
    ubuntu|debian)   PKG="apt";  DISTRO_OK=1 ;;
    opensuse*|suse|sles) PKG="zypper"; DISTRO_OK=1 ;;
    ol|rhel|centos|rocky|almalinux) PKG="dnf"; DISTRO_OK=1 ;;
    arch|manjaro)    PKG="pacman"; DISTRO_OK=1 ;;
esac

if [[ "$DISTRO_OK" -eq 0 ]]; then
    echo -e "${RED}❌ Sistema no soportado: $ID${RESET}"
    echo -e "${WHITE}   Soportados: Ubuntu, Debian, openSUSE Leap, Oracle Linux, Arch Linux${RESET}"
    exit 1
fi

# Funciones de gestión de paquetes (abstracción)
pkg_update() {
    case "$PKG" in
        apt)    apt-get update -y ;;
        zypper) zypper --non-interactive refresh ;;
        dnf)    dnf makecache -y ;;
        pacman) pacman -Sy --noconfirm ;;
    esac
}

pkg_install() {
    case "$PKG" in
        apt)    apt-get install -y "$@" ;;
        zypper) zypper --non-interactive install -y "$@" ;;
        dnf)    dnf install -y "$@" ;;
        pacman) pacman -S --noconfirm --needed "$@" ;;
    esac
}

pkg_remove() {
    case "$PKG" in
        apt)    apt-get purge -y "$@" ;;
        zypper) zypper --non-interactive remove -y "$@" ;;
        dnf)    dnf remove -y "$@" ;;
        pacman) pacman -Rns --noconfirm "$@" ;;
    esac
}

pkg_clean() {
    case "$PKG" in
        apt)    apt-get autoremove -y; apt-get clean ;;
        zypper) zypper clean ;;
        dnf)    dnf autoremove -y; dnf clean all ;;
        pacman) pacman -Scc --noconfirm ;;
    esac
}

pkg_installed() {
    case "$PKG" in
        apt)    dpkg -l 2>/dev/null | grep -q "^ii.*${1}" ;;
        zypper) rpm -q "$1" >/dev/null 2>&1 ;;
        dnf)    rpm -q "$1" >/dev/null 2>&1 ;;
        pacman) pacman -Qi "$1" >/dev/null 2>&1 ;;
    esac
}

pkg_hold() {
    case "$PKG" in
        apt)    apt-mark hold "$1" >/dev/null 2>&1 ;;
        dnf)    echo "$1" >> /etc/dnf/protected.d/movivip.conf 2>/dev/null ;;
        zypper) true ;;
        pacman) true ;;
    esac
}

pkg_unhold() {
    case "$PKG" in
        apt)    apt-mark unhold "$1" >/dev/null 2>&1 ;;
        dnf)    rm -f /etc/dnf/protected.d/movivip.conf 2>/dev/null ;;
        zypper) true ;;
        pacman) true ;;
    esac
}

pkg_list_removable() {
    case "$PKG" in
        apt)    apt list --installed 2>/dev/null | grep -i "$1" ;;
        dnf)    rpm -qa | grep -i "$1" ;;
        zypper) rpm -qa | grep -i "$1" ;;
        pacman) pacman -Qs "$1" 2>/dev/null ;;
    esac
}

# Iniciar log de instalación
echo "========== INSTALACIÓN MoviVIP v6.0 — $(date) ==========" > "$INSTALL_LOG"
chmod 600 "$INSTALL_LOG"

clear
echo -e "${GREEN}✔ Sistema detectado: ${PRETTY_NAME:-$ID}${RESET}"
echo -e "${WHITE}  Gestor de paquetes: ${PKG}${RESET}"

# ==============================
# GATE DE LICENCIA (ANTI-PIRATERÍA)
# Valida contra Firebase antes de instalar CUALQUIER cosa.
# Sin licencia válida -> instalación BLOQUEADA.
# Si ya hay licencia válida guardada (ej: desde install-con-licencia.sh),
# se salta la validación interactiva.
# ==============================

GATE_URL="https://raw.githubusercontent.com/studioanime977/vps-license-gate/main/gate/validar-licencia.sh"
GATE_TMP="/tmp/validar-licencia-movivip.sh"

# ═══════════════════════════════════════════════════════════════
# SOPORTE KEY v2 (runner embebido en GitHub Releases)
# Una key v2 puede ser:
#   - CORTA (v2.0.3+): base64 raw 64 chars (payload binario 24B + HMAC 24B, reseller "movivipnetwork")
#   - CORTA L (v2.0.2): base64 raw 40 chars (payload binario 15B + HMAC 15B, retro-compat keys vendidas)
#   - LARGA: AES-256-CBC+HMAC, payload JSON (retro-compat, keys existentes)
# La validación la hace el runner compilado (tiene la master key dentro,
# NUNCA se expone la master key en texto plano en install.sh público).
# ═══════════════════════════════════════════════════════════════
MOVIVIP_RUNNER_BIN="/tmp/movivip-runner"
# Soporte multi-arquitectura: el runner se publica para 5 plataformas
# (amd64, arm64, ppc64le, riscv64, s390x). Detectar con uname -m.
_detect_runner_arch() {
    local M
    M=$(uname -m 2>/dev/null | tr '[:upper:]' '[:lower:]')
    case "$M" in
        x86_64|amd64)  echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        ppc64le|ppc64) echo "ppc64le" ;;
        riscv64|riscv)  echo "riscv64" ;;
        s390x)         echo "s390x" ;;
        *) echo "amd64" ;;  # fallback conservador
    esac
}
_RUNNER_ARCH="$(_detect_runner_arch)"
MOVIVIP_RUNNER_URL="https://github.com/studioanime977/MoviVIPNetwork/releases/download/v7.4.4/movivip-runner-linux-${_RUNNER_ARCH}"

is_v2_key() {
    local key="$1"
    [[ -n "$key" ]] \
        && [[ "${#key}" -eq 40 || "${#key}" -eq 64 ]] \
        && [[ ! "$key" =~ ^KEY-[A-Fa-f0-9]{10}$ ]]
}

validate_v2_key() {
    local key="$1"
    # v7.4.5: LOCAL-FIRST — el runner viene EMPAQUETADO dentro del payload
    # (extraído a /usr/local/movivip-src/bin/ por el bootstrapper). Cero
    # descargas externas en el flujo normal: instalación 100% offline.
    if [[ ! -x "$MOVIVIP_RUNNER_BIN" ]]; then
        local _pkg_runner=""
        local _cands=(
            "${MOVIVIP_SRC:-/usr/local/movivip-src}/bin/movivip-runner-linux-${_RUNNER_ARCH}"
            "${MOVIVIP_SRC:-/usr/local/movivip-src}/bin/movivip-runner"
            "/etc/movivip/bin/movivip-runner-linux-${_RUNNER_ARCH}"
            "/etc/movivip/bin/movivip-runner"
        )
        for _c in "${_cands[@]}"; do
            if [[ -s "$_c" ]]; then _pkg_runner="$_c"; break; fi
        done
        if [[ -n "$_pkg_runner" ]]; then
            cp -f "$_pkg_runner" "$MOVIVIP_RUNNER_BIN" 2>/dev/null
            chmod +x "$MOVIVIP_RUNNER_BIN" 2>/dev/null
        fi
    fi
    # ÚLTIMO recurso: descargar runner compilado (solo si no hay copia local)
    if [[ ! -x "$MOVIVIP_RUNNER_BIN" ]]; then
        command -v curl >/dev/null 2>&1 || pkg_install curl >/dev/null 2>&1
        curl -fsSL --max-time 120 "$MOVIVIP_RUNNER_URL" -o "$MOVIVIP_RUNNER_BIN" 2>/dev/null || return 1
        chmod +x "$MOVIVIP_RUNNER_BIN" 2>/dev/null || return 1
    fi
    if "$MOVIVIP_RUNNER_BIN" verify "$key" >/dev/null 2>&1; then
        return 0
    fi
    # Fallback: el binario cacheado puede ser viejo/roto (no soporta key v2).
    # Reintentar con la copia local fresca del payload (sin redescargar).
    rm -f "$MOVIVIP_RUNNER_BIN"
    local _pkg2=""
    local _cands2=(
        "${MOVIVIP_SRC:-/usr/local/movivip-src}/bin/movivip-runner-linux-${_RUNNER_ARCH}"
        "/etc/movivip/bin/movivip-runner-linux-${_RUNNER_ARCH}"
    )
    for _c in "${_cands2[@]}"; do
        if [[ -s "$_c" ]]; then _pkg2="$_c"; break; fi
    done
    if [[ -n "$_pkg2" ]]; then
        cp -f "$_pkg2" "$MOVIVIP_RUNNER_BIN" 2>/dev/null
        chmod +x "$MOVIVIP_RUNNER_BIN" 2>/dev/null
        "$MOVIVIP_RUNNER_BIN" verify "$key" >/dev/null 2>&1
        return $?
    fi
    # Redescarga única como último fallback
    command -v curl >/dev/null 2>&1 || pkg_install curl >/dev/null 2>&1
    curl -fsSL --max-time 120 "$MOVIVIP_RUNNER_URL" -o "$MOVIVIP_RUNNER_BIN" 2>/dev/null || return 1
    chmod +x "$MOVIVIP_RUNNER_BIN" 2>/dev/null || return 1
    "$MOVIVIP_RUNNER_BIN" verify "$key" >/dev/null 2>&1
}

# Verificar si ya existe licencia válida.
# Fuentes (en orden):
#   1. Argumento CLI "key:XXXX" o key directa  — instalación automática (install.sh key:...)
#   2. Variable de entorno LICENCIA_KEY — cuando install-con-licencia.sh la pasa
#   3. /tmp/movivip-key.txt — fallback cuando /etc/movivip fue borrado
#   4. /etc/movivip/licencia.conf — cuando se ejecuta directamente sobre instalación previa
# Bypass de licencia — acceso libre (sin key requerida)
LICENSE_VALID="yes"
INCOMING_KEY="KEY-37549D57B2"
DETECTED_KEY="KEY-37549D57B2"
AUTO_INSTALL=1

# Detectar key desde cualquier fuente (CLI key: > env LICENCIA_KEY > /tmp/movivip-key.txt > licencia.conf)
# (mantenido por compatibilidad, ya no bloquea)
if [[ -n "${1:-}" && ( "$1" == key:* || "${#1}" -eq 40 || "${#1}" -eq 64 || "$1" =~ ^KEY-[A-Fa-f0-9]{10}$ ) ]]; then
    # Acepta: install.sh key:LARGAKEY | install.sh LARGAKEY (40/64) | install.sh KEY-XXXX
    DETECTED_KEY="$(echo "${1#key:}" | tr -d '[:space:]')"
    if [[ -n "$DETECTED_KEY" ]]; then
        echo "$DETECTED_KEY" > /tmp/movivip-key.txt 2>/dev/null
        chmod 600 /tmp/movivip-key.txt 2>/dev/null
    fi
elif [[ -n "$LICENCIA_KEY" ]]; then
    DETECTED_KEY="$LICENCIA_KEY"
elif [[ -f /tmp/movivip-key.txt ]]; then
    DETECTED_KEY=$(cat /tmp/movivip-key.txt 2>/dev/null | tr -d '[:space:]')
elif [[ -f /etc/movivip/licencia.conf ]]; then
    source /etc/movivip/licencia.conf 2>/dev/null
    DETECTED_KEY="${KEY:-}"
fi

INCOMING_KEY="$DETECTED_KEY"

# ── MODO INSTALACIÓN AUTOMÁTICA (v8.2.1) ──
# Si se detecta una key (argumento CLI, env LICENCIA_KEY, /tmp/movivip-key.txt o
# licencia.conf previa) → AUTO_INSTALL=1: se salta TODO prompt interactivo y se
# instala con los valores por defecto (plan PREMIUM, versión ESTABLE, zonas sin
# cambiar, protocolos TODOS). Así el cliente puede correr el comando + su key
# sin intervención manual.
# Para reinstalar interactivamente, forzar: AUTO_INSTALL=0 bash install.sh
AUTO_INSTALL="${AUTO_INSTALL:-0}"
if [[ -n "$DETECTED_KEY" ]]; then
    AUTO_INSTALL=1
fi
export AUTO_INSTALL

if [[ -n "$DETECTED_KEY" ]]; then
    if [[ "$DETECTED_KEY" =~ ^KEY-[A-Fa-f0-9]{10}$ ]]; then
        # Key legacy: ya verificada en instalaciones previas
        LICENSE_VALID="yes"
    elif is_v2_key "$DETECTED_KEY"; then
        # Key v2: validar con el runner compilado (nunca exponer la master key)
        echo ""
        echo "$(trx '🔑 Key v2 detectada — validando con el runner...')"
        if validate_v2_key "$DETECTED_KEY"; then
            echo -e "${GREEN}$(trx '✔ LICENCIA V2 VALIDADA (ya verificada)')${RESET}"
            LICENSE_VALID="yes"
        else
            LICENSE_VALID="no"
        fi
        echo ""
    fi
fi

# Registro de activación — definición GLOBAL (disponible para la rama
# rápida "key legacy ya verificada" y para la rama de validación en vivo)
registrar_activacion() {
    local key="${1:-}" ip="" host="" node="" ts=""
    [[ -z "$key" ]] && return 0
    ip=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || curl -s --max-time 10 icanhazip.com 2>/dev/null || echo "unknown")
    host=$(hostname 2>/dev/null || echo "unknown")
    node=$(echo "$key" | tr '+/' '-_')
    ts=$(date +%s)
    # (1) canal preferido: backend del bot
    curl -s --max-time 15 -X POST "https://bot.movivipoppax.uk/api/activacion" \
        -H "Content-Type: application/json" \
        -d "{\"key\":\"${key}\",\"ip\":\"${ip}\",\"hostname\":\"${host}\"}" >/dev/null 2>&1
    # (2) keygenbpt = store PUBLICO de activaciones (escritura libre, la que
    #     usan registrar_ips / check-licencia.sh). Formato identico a las
    #     activaciones legacy: activaciones_movivip/<node>/<ts>.json
    curl -s --max-time 15 -X PATCH \
        "https://keygenbpt-default-rtdb.firebaseio.com/activaciones_movivip/${node}.json" \
        -H "Content-Type: application/json" \
        -d "{\"${ts}\":{\"fecha\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"hostname\":\"${host}\",\"ip\":\"${ip}\"}}" >/dev/null 2>&1
    # (3) movivip-network: best-effort silencioso (reglas actuales devuelven
    #     401 en escritura anonima; si algun dia se abren, queda registrado)
    curl -s --max-time 15 -X PUT \
        "https://movivip-network-default-rtdb.firebaseio.com/activaciones_movivip/${node}/${ts}.json" \
        -H "Content-Type: application/json" \
        -d "{\"ip\":\"${ip}\",\"hostname\":\"${host}\",\"fecha\":\"$(date '+%Y-%m-%d %H:%M:%S')\"}" >/dev/null 2>&1
}

if [[ "$LICENSE_VALID" == "yes" ]]; then
    echo ""
    echo "$(mv_hr)"
    echo "$(trx '      🔑 LICENCIA VALIDADA (ya verificada)')"
    echo "$(mv_hr)"
    echo ""
    echo -e "${GREEN}✔ Licencia previa detectada: $(echo "${INCOMING_KEY}" | head -c 12)... — continuando...${RESET}"
    echo ""
    # FIX v8.2.14: registrar activación TAMBIÉN en la rama rápida (key legacy
    # detectada por CLI/env). Antes solo corría dentro del else de validación
    # en vivo → el flujo normal del cliente (install.sh KEY-XXXX) NUNCA
    # registraba en Firebase ni creaba /etc/movivip/activaciones/.
    if [[ -n "${INCOMING_KEY:-}" ]]; then
        registrar_activacion "${INCOMING_KEY}"
        mkdir -p /etc/movivip/activaciones
        DEVICE_ID=$(cat /etc/machine-id 2>/dev/null | head -c 16 || echo "unknown")
        if [[ "$DEVICE_ID" == "unknown" ]]; then
            VPS_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "unknown")
            DEVICE_ID=$(echo -n "${VPS_IP}$(date +%s)" | sha256sum | head -c 16)
        fi
        VPS_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "unknown")
        echo "${VPS_IP}" > "/etc/movivip/activaciones/${DEVICE_ID}.ip"
        echo "$(date +%s)" > "/etc/movivip/activaciones/${DEVICE_ID}.timestamp"
        echo "${INCOMING_KEY}" > "/etc/movivip/activaciones/${DEVICE_ID}.key"
    fi
else
    echo ""
    echo "$(mv_hr)"
    echo "$(trx '      🔑 VALIDACIÓN DE LICENCIA')"
    echo "$(mv_hr)"
    echo ""

    # Asegurar curl (si apt estaba roto, usar la auto-reparación del gate)
    command -v curl >/dev/null 2>&1 || pkg_install curl >/dev/null 2>&1

    # Descargar el módulo de validación (siempre la última versión, con barra animada)
    curl -fsSL --max-time 30 "$GATE_URL" -o "$GATE_TMP" 2>/dev/null &
    GATE_DL_PID=$!
    GATE_DL_PCT=0
    while kill -0 "$GATE_DL_PID" 2>/dev/null; do
        GATE_DL_PCT=$(( GATE_DL_PCT + 5 ))
        [[ $GATE_DL_PCT -gt 92 ]] && GATE_DL_PCT=92
        _anim_bar "$GATE_DL_PCT" "descargando módulo de licencia ..."
        sleep 0.12
    done
    wait "$GATE_DL_PID"
    if [[ $? -ne 0 || ! -s "$GATE_TMP" ]]; then
        printf "\r\033[K"
        echo "$(trx '❌ No se pudo cargar el módulo de validación de licencia.')"
        echo "$(trx '   Verifica tu conexión a internet y reintenta.')"
        echo ""
        echo "$(trx '   📞 Contacto:')"
        echo "   ─────────────────────────────────────────────"
        echo "$(trx '   💬 Telegram : @MoviVIP')"
        echo "$(trx '   📱 WhatsApp : +57 311 700 8185')"
        echo "   🌐 Web      : https://movivip-network.web.app"
        echo "   📢 Canal    : https://t.me/MoviVIPNetwork"
        echo "   👥 Grupo    : https://t.me/MoviVIPNet"
        echo "   📢 Canal    : https://t.me/NetSphereCol"
        echo "   📢 Canal    : https://t.me/FreeNetZonevip"
        echo "   👥 Grupo    : https://t.me/FreeNetZonevips"
        echo "   ─────────────────────────────────────────────"
        echo ""
        exit 1
    fi
    printf "\r\033[K   ✔ Módulo de licencia descargado correctamente\n"

    chmod +x "$GATE_TMP"

    # Ejecutar la validación (acepta key legacy KEY-XXXX y key v2 larga)
    # Si aún no hay key detectable, preguntarla una sola vez y decidir el validador.
    if [[ -z "${INCOMING_KEY:-}" ]]; then
        echo ""
        if [[ -t 0 ]]; then
            read -r -p "$(trx '🔑 Introduce tu key de licencia: ')" USER_INPUT_KEY
            INCOMING_KEY="$(echo "${USER_INPUT_KEY:-}" | tr -d '[:space:]')"
        else
            # Sin TTY (instalación remota) → no bloquear, usar fuentes previas
            if [[ -f /tmp/movivip-key.txt ]]; then
                INCOMING_KEY="$(cat /tmp/movivip-key.txt 2>/dev/null | tr -d '[:space:]')"
            fi
            [[ -n "$INCOMING_KEY" ]] || { echo "$(trx '❌ No hay key disponible (instalación sin terminal).')"; echo "$(trx '   Pasa la key como argumento: bash install.sh TU_CLAVE')"; exit 1; }
        fi
    fi

    if is_v2_key "$INCOMING_KEY"; then
        # KEY V2 → validar con el runner compilado (único que conoce la master key)
        echo ""
        echo "$(trx '🔑 Key v2 detectada — validando con el runner...')"
        if validate_v2_key "$INCOMING_KEY"; then
            LICENSE_VALID="yes"
            GATE_RESULT=0
        else
            # FALLBACK (FIX v7.0.1): el runner no reconoció la key → validar contra Firebase
            # El gate consulta licencias_movivip/{KEY}.json y acepta keys de 40/64 chars.
            echo "$(trx '⚠ El runner no reconoció la key — intentando validación Firebase...')"
            if [[ -s "$GATE_TMP" ]]; then
                bash "$GATE_TMP" "$INCOMING_KEY"
                GATE_RESULT=$?
                [[ $GATE_RESULT -eq 0 ]] && LICENSE_VALID="yes"
            else
                GATE_RESULT=1
            fi
        fi
    elif [[ -n "$INCOMING_KEY" ]]; then
        # KEY LEGACY → validar con el gate (Firebase), pasándole la key como argumento
        bash "$GATE_TMP" "$INCOMING_KEY"
        GATE_RESULT=$?
    else
        bash "$GATE_TMP"
        GATE_RESULT=$?
    fi

    if [[ $GATE_RESULT -ne 0 ]]; then
        echo ""
        echo "$(mv_hr)"
        echo "$(trx '   ⛔ INSTALACIÓN BLOQUEADA — LICENCIA NO VÁLIDA')"
        echo "$(mv_hr)"
        echo ""
        echo "$(trx '   Este sistema requiere una clave de licencia válida.')"
        echo ""
        echo "$(trx '   🔑 Adquiere tu licencia aquí:')"
        echo "   ─────────────────────────────────────────────"
        echo "$(trx '   💬 Telegram : @MoviVIP')"
        echo "$(trx '   📱 WhatsApp : +57 311 700 8185')"
        echo "   🌐 Web      : https://movivip-network.web.app"
        echo "   📢 Canal    : https://t.me/MoviVIPNetwork"
        echo "   👥 Grupo    : https://t.me/MoviVIPNet"
        echo "   📢 Canal    : https://t.me/NetSphereCol"
        echo "   📢 Canal    : https://t.me/FreeNetZonevip"
        echo "   👥 Grupo    : https://t.me/FreeNetZonevips"
        echo "   ─────────────────────────────────────────────"
        echo ""
        exit 1
    fi

    echo ""
    echo -e "${GREEN}✔ LICENCIA VALIDADA — CONTINUANDO INSTALACIÓN...${RESET}"
    echo ""

    # ══════════════════════════════════════════════════════════════
    # REGISTRO DE ACTIVACIÓN EN FIREBASE RTDB (unificado legacy + v2)
    # Fix v8.2.12: antes solo se registraba si YA existía
    # /etc/movivip/gate/validar-licencia.sh (en instalación fresca el
    # gate se copia después → el bloque moría) y además las keys v2
    # validadas por el runner nunca llegaban a registrar porque el
    # gate (responsable del registro) no se ejecutaba en esa rama.
    # Ahora el instalador registra SIEMPRE:
    #   (1) POST al backend del bot   (canal preferido, token del bot)
    #   (2) PUT  movivip-network / activaciones_movivip / <nodo> / <ts>
    #   (3) espejo keygenbpt / activaciones_movivip / <nodo>
    #       (mismo nodo url-safe que gate, generador y registrar_ips:
    #        legacy KEY-... intacta, v2 con '+'/'/' → '-'/'_')
    # ══════════════════════════════════════════════════════════════
    registrar_activacion() {
        local key="${1:-}" ip="" host="" node="" ts=""
        [[ -z "$key" ]] && return 0
        ip=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || curl -s --max-time 10 icanhazip.com 2>/dev/null || echo "unknown")
        host=$(hostname 2>/dev/null || echo "unknown")
        node=$(echo "$key" | tr '+/' '-_')
        ts=$(date +%s)
        # (1) canal preferido: backend del bot
        curl -s --max-time 15 -X POST "https://bot.movivipoppax.uk/api/activacion" \
            -H "Content-Type: application/json" \
            -d "{\"key\":\"${key}\",\"ip\":\"${ip}\",\"hostname\":\"${host}\"}" >/dev/null 2>&1
        # (2) keygenbpt = store PUBLICO de activaciones (escritura libre, la que
        #     usan registrar_ips / check-licencia.sh). Formato identico a las
        #     activaciones legacy: activaciones_movivip/<node>/<ts>.json
        curl -s --max-time 15 -X PATCH \
            "https://keygenbpt-default-rtdb.firebaseio.com/activaciones_movivip/${node}.json" \
            -H "Content-Type: application/json" \
            -d "{\"${ts}\":{\"fecha\":\"$(date '+%Y-%m-%d %H:%M:%S')\",\"hostname\":\"${host}\",\"ip\":\"${ip}\"}}" >/dev/null 2>&1
        # (3) movivip-network: best-effort silencioso (reglas actuales devuelven
        #     401 en escritura anonima; si algun dia se abren, queda registrado)
        curl -s --max-time 15 -X PUT \
            "https://movivip-network-default-rtdb.firebaseio.com/activaciones_movivip/${node}/${ts}.json" \
            -H "Content-Type: application/json" \
            -d "{\"ip\":\"${ip}\",\"hostname\":\"${host}\",\"fecha\":\"$(date '+%Y-%m-%d %H:%M:%S')\"}" >/dev/null 2>&1
    }
    if [[ -n "${INCOMING_KEY:-}" ]]; then
        registrar_activacion "${INCOMING_KEY}"
        # Guardar localmente para referencia
        mkdir -p /etc/movivip/activaciones
        DEVICE_ID=$(cat /etc/machine-id 2>/dev/null | head -c 16 || echo "unknown")
        if [[ "$DEVICE_ID" == "unknown" ]]; then
            VPS_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "unknown")
            DEVICE_ID=$(echo -n "${VPS_IP}$(date +%s)" | sha256sum | head -c 16)
        fi
        VPS_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "unknown")
        echo "${VPS_IP}" > "/etc/movivip/activaciones/${DEVICE_ID}.ip"
        echo "$(date +%s)" > "/etc/movivip/activaciones/${DEVICE_ID}.timestamp"
        echo "${INCOMING_KEY}" > "/etc/movivip/activaciones/${DEVICE_ID}.key"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# NOTIFICACIÓN DE ACTIVACIÓN — Telegram Bot
# Fix v8.2.12: la notificación se dispara DESPUÉS de copiar el
# payload (bloque al final del instalador). Antes se intentaba aquí,
# donde en instalación fresca NO existe /etc/movivip/herramientas/
# ni .env-bot → el fallback salía silencioso y nunca llegaba nada.
# (El bloque final restaura .env-bot vía env-bot-sync.sh si hace falta)
# ═══════════════════════════════════════════════════════════════

# Persistir el gate localmente: los protocolos y el bot lo usan
# (check-licencia.sh) para validar la key contra Firebase EN VIVO
# antes de cada instalación/gestión de protocolo.
mkdir -p /etc/movivip
mkdir -p /etc/movivip/gate

# Guardar licencia recibida de install-con-licencia.sh
if [[ "$LICENSE_VALID" == "yes" ]] && [[ -n "$INCOMING_KEY" ]]; then
    # ── FIX v8.2.5: FIREBASE_BASE SIEMPRE definida aquí ──
    # Antes solo se definía dentro de la rama else de validación (L923);
    # si la key v2 la valida el runner local (rama rápida), quedaba VACÍA
    # y el curl de abajo fallaba (URL https:///...) → la licencia se
    # persistía como standard aunque el plan REAL en Firebase fuera
    # bronce/premium.
    FIREBASE_BASE="${FIREBASE_BASE:-movivip-network-default-rtdb.firebaseio.com}"
    # ── SEGURIDAD: el plan/cliente/tipo SIEMPRE se leen de Firebase ──
    # (el archivo local es editable por el cliente; nunca confiar en él)
    FB_REAL_PLAN="standard"; FB_REAL_CLIENTE="desconocido"; FB_REAL_TIPO="cliente"
    FB_REAL_EXPIRA="0"; FB_REAL_ACTIVA="false"
    FB_KEY_PATH="$INCOMING_KEY"
    if is_v2_key "$INCOMING_KEY"; then
        FB_KEY_PATH=$(echo "$INCOMING_KEY" | tr '+/' '-_')
    fi
    FB_PLAN_RESP=""
    FB_PLAN_RESP=$(curl -s --max-time 12 "https://${FIREBASE_BASE}/licencias_movivip/${FB_KEY_PATH}.json" 2>/dev/null)
    if [[ -n "$FB_PLAN_RESP" && "$FB_PLAN_RESP" != "null" ]]; then
        FB_REAL_PLAN=$(echo "$FB_PLAN_RESP" | grep -o '"plan"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*:"//;s/"$//')
        FB_REAL_CLIENTE=$(echo "$FB_PLAN_RESP" | grep -o '"cliente"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*:"//;s/"$//')
        FB_REAL_TIPO=$(echo "$FB_PLAN_RESP" | grep -o '"tipo"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*:"//;s/"$//')
        FB_REAL_EXPIRA=$(echo "$FB_PLAN_RESP" | grep -o '"expira"[[:space:]]*:[[:space:]]*[0-9]*' | head -n1 | sed 's/.*://')
        FB_REAL_ACTIVA=$(echo "$FB_PLAN_RESP" | grep -o '"activa":[a-z]*' | head -n1 | cut -d: -f2)
        [[ -z "$FB_REAL_PLAN" ]] && FB_REAL_PLAN="standard"
        [[ -z "$FB_REAL_CLIENTE" ]] && FB_REAL_CLIENTE="desconocido"
        [[ -z "$FB_REAL_TIPO" ]] && FB_REAL_TIPO="cliente"
        [[ -z "$FB_REAL_EXPIRA" ]] && FB_REAL_EXPIRA="0"
        [[ -z "$FB_REAL_ACTIVA" ]] && FB_REAL_ACTIVA="false"
        # Si Firebase dice inactiva, no persistir con plan alto
        if [[ "$FB_REAL_ACTIVA" != "true" ]]; then
            FB_REAL_PLAN="standard"; FB_REAL_CLIENTE="desconocido"; FB_REAL_TIPO="cliente"
        fi
    fi
    cat > /etc/movivip/licencia.conf << LICEOF
# Movivip Network — Licencia (sincronizada con Firebase EN VIVO)
# ⚠ NO edites este archivo: se sobreescribe en cada validación.
KEY="$INCOMING_KEY"
PLAN="$FB_REAL_PLAN"
CLIENTE="$FB_REAL_CLIENTE"
TIPO="$FB_REAL_TIPO"
EXPIRA="$FB_REAL_EXPIRA"
FECHA_ACTIVACION="$(date +%Y-%m-%d)"
LICEOF
    echo -e "${GREEN}✔ Licencia persistida en /etc/movivip/licencia.conf${RESET}"
fi

# Solo copiar el gate si se descargó (no cuando ya existía licencia válida)
if [[ -f "$GATE_TMP" ]]; then
    cp "$GATE_TMP" /etc/movivip/validar-licencia.sh
    chmod +x /etc/movivip/validar-licencia.sh
    cp "$GATE_TMP" /etc/movivip/gate/validar-licencia.sh
    chmod +x /etc/movivip/gate/validar-licencia.sh
    echo -e "${GREEN}✔ Gate de licencia instalado localmente.${RESET}"
else
    # Descargar el gate para persistirlo (necesario para protocolos futuros)
    command -v curl >/dev/null 2>&1 || pkg_install curl >/dev/null 2>&1
    if curl -fsSL --max-time 30 "$GATE_URL" -o /etc/movivip/validar-licencia.sh 2>/dev/null; then
        chmod +x /etc/movivip/validar-licencia.sh
        cp /etc/movivip/validar-licencia.sh /etc/movivip/gate/validar-licencia.sh
        echo -e "${GREEN}✔ Gate de licencia instalado localmente.${RESET}"
    elif [[ -f "${MOVIVIP_SRC:-}/validar-licencia.sh" ]]; then
        # Fix v8.2.12: fallback al gate EMPAQUETADO (v2-capable) si no hay red
        cp -f "${MOVIVIP_SRC}/validar-licencia.sh" /etc/movivip/validar-licencia.sh
        chmod +x /etc/movivip/validar-licencia.sh
        cp -f "${MOVIVIP_SRC}/validar-licencia.sh" /etc/movivip/gate/validar-licencia.sh
        chmod +x /etc/movivip/gate/validar-licencia.sh
        echo -e "${GREEN}✔ Gate empaquetado instalado (offline).${RESET}"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# SELECTOR DE IDIOMA — INTERACTIVO
# ═══════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}$(mv_hr)${RESET}"
echo -e "${GOLD}      🌐 SELECTOR DE IDIOMA / LANGUAGE SELECTOR${RESET}"
echo -e "${CYAN}$(mv_hr)${RESET}"
echo ""
echo -e "${WHITE}  🌍 Elige el idioma de todas las preguntas y menús:${RESET}"
echo -e "${GRAY}  (El español es el idioma principal del sistema)${RESET}"
echo ""

# Lista de idiomas: código|bandera|nombre|región
LANG_LIST=(
    "es|🇪🇸|Español|España/Latinoamérica"
    "en|🇺🇸|Inglés|Estados Unidos/Reino Unido"
    "af|🇪🇹|Afaan Oromoo|Etiopía/Kenia"
    "fr|🇫🇷|Francés|Francia/Bélgica"
    "pt|🇧🇷|Portugués|Brasil/Portugal"
    "ar|🇸🇦|Árabe|Arabia Saudita/Egipto"
    "sw|🇰🇪|Kiswahili|Kenia/Tanzania"
    "de|🇩🇪|Alemán|Alemania/Austria"
    "zh|🇨🇳|Chino|China"
    "hi|🇮🇳|Hindi|India"
)

INSTALL_LANG="es"
for i in "${!LANG_LIST[@]}"; do
    IFS='|' read -r code flag name region <<< "${LANG_LIST[$i]}"
    num=$((i + 1))
    printf "  ${CYAN}[%02d]${RESET} ${WHITE}%s %-15s${RESET} ${GRAY}%-20s${RESET}\n" \
        "$num" "$flag" "$name" "$region"
done

echo ""
if [[ -t 0 && "$AUTO_INSTALL" == "0" ]]; then
    read -rp "$(echo -e "${CYAN}➜ ${GOLD}Selecciona el idioma [1-10]${WHITE} (por defecto: 1=Español) ➤ ${RESET}")" LANG_CHOICE
else
    LANG_CHOICE="${LANG_CHOICE:-1}"
fi
LANG_CHOICE="${LANG_CHOICE:-1}"
[[ "$LANG_CHOICE" =~ ^[0-9]+$ ]] || LANG_CHOICE=1

# Mapear número a código
LANG_CODES=("es" "en" "af" "fr" "pt" "ar" "sw" "de" "zh" "hi")
LANG_IDX=$((LANG_CHOICE - 1))
if [[ $LANG_IDX -ge 0 && $LANG_IDX -lt ${#LANG_CODES[@]} ]]; then
    INSTALL_LANG="${LANG_CODES[$LANG_IDX]}"
else
    INSTALL_LANG="es"
fi

echo -e "${GREEN}✅ Idioma seleccionado: ${WHITE}${INSTALL_LANG^^}${RESET}"
sleep 1

# ═══════════════════════════════════════════════════════════════
# WELCOME 3D INTERACTIVO — PRECIOS · VERSIÓN · ZONA HORARIA (v8.3)
# Reconstruido según especificación del usuario; estilo NEBULA v3.0
# (misma paleta ANSI-256 y logo 3D que lib/ui.sh · mv_banner_3d)
# ═══════════════════════════════════════════════════════════════

# Logotipo MOVIVIP 3D (banner oficial de marca - extraido del heredoc BEOF en runtime)
_az3="\e[38;5;39m"; _ci3="\e[38;5;51m"; _go3="\e[38;5;220m"; _am3="\e[38;5;226m"
_mg3="\e[38;5;201m"; _na3="\e[38;5;208m"; _bl3="\e[38;5;255m"; _rs3="\e[0m"

# Valores por defecto (precios ESTATICOS informativos en USDT); plan REAL de la key
WELCOME_PLAN="${FB_REAL_PLAN:-premium}"
case "$WELCOME_PLAN" in
    bronce)   WELCOME_PLAN_COSTO="5" ;;
    platino)  WELCOME_PLAN_COSTO="35" ;;
    vitalicio|beta) WELCOME_PLAN_COSTO="100" ;;
    *)        WELCOME_PLAN_COSTO="15" ;;
esac
WELCOME_VERSION="${INSTALL_VERSION:-stable}"
WELCOME_TZ="${SYS_TZ:-}"

# Cabecera 3D: ejecuta el banner oficial de login (heredoc BEOF) sin duplicar codigo
clear
_TMP_BANNER="$(mktemp 2>/dev/null || echo /tmp/movivip-banner-welcome.sh)"
if sed -n "/MoviVIP-banner.sh << .BEOF./,/^BEOF$/p" "$0" | sed "1d;\$d" | grep -v "\[\[ \$-" > "$_TMP_BANNER"; then
    bash "$_TMP_BANNER" 2>/dev/null
fi
rm -f "$_TMP_BANNER" 2>/dev/null

# Precios de planes informativos y estaticos (NO se eligen durante la instalacion)
echo ""
echo -e "${_bl3}   Los precios de planes son informativos y estaticos:${_rs3}"
echo -e "${_ci3}   [BRONCE 5 USDT - 1 disp]   [PREMIUM 15 USDT - 2 disp]   [BETA=VITALICIA 100 USDT]${_rs3}"
echo ""

# ── 2) Selección de versión ──
if [[ -t 0 && "$AUTO_INSTALL" == "0" ]]; then
    echo ""
    echo -e "${_ci3}   ╔════════════════════════════════════════════════╗${_rs3}"
    echo -e "${_ci3}   ║${_go3}        🚀 SELECCIÓN DE VERSIÓN DE SCRIPT${_rs3}${_ci3}        ║${_rs3}"
    echo -e "${_ci3}   ╠════════════════════════════════════════════════╣${_rs3}"
    echo -e "${_ci3}   ║${_am3}  [1] ${_bl3}ESTABLE  ${_go3}· probada en producción${_rs3}${_ci3}    ║${_rs3}"
    echo -e "${_ci3}   ║${_am3}  [2] ${_bl3}BETA     ${_go3}· novedades experimentales${_rs3}${_ci3} ║${_rs3}"
    echo -e "${_ci3}   ╚════════════════════════════════════════════════╝${_rs3}"
    read -rp "$(echo -e "${_ci3}➤ ${_bl3}Elige la versión [1-2] ${_go3}(por defecto: 1=ESTABLE)${_rs3} ➤ ")" WELCOME_VERSION_CHOICE
    WELCOME_VERSION_CHOICE="${WELCOME_VERSION_CHOICE:-1}"
    case "${WELCOME_VERSION_CHOICE:-1}" in
        2) WELCOME_VERSION="beta" ;;
        *) WELCOME_VERSION="stable" ;;
    esac
fi

# ──────────────────────────────────────────────────────────────
# SELECTOR DE ZONA HORARIA — lista TODAS las zonas del mundo
# Fuente: timedatectl list-timezones (fallback: /usr/share/zoneinfo)
# Navegación: [número] elegir · [n/Enter] siguiente · [p] anterior
#            · [b] buscar · [0] salir sin cambios
# ──────────────────────────────────────────────────────────────
_mv_tz_list() {
    if command -v timedatectl >/dev/null 2>&1 && timedatectl list-timezones >/dev/null 2>&1; then
        timedatectl list-timezones 2>/dev/null
    elif [[ -d /usr/share/zoneinfo ]]; then
        find /usr/share/zoneinfo -type f 2>/dev/null | sed 's|^/usr/share/zoneinfo/||' | grep -vE '^(posix|right)/' | sort -u
    fi
}

# Devuelve la zona elegida en $WELCOME_TZ (vacía si cancela)
_mv_tz_pick() {
    local -a _ZONES=() _VIEW=()
    local _line _i _from _to _total _vtot _cmd _filter="" _sel=""
    local _page=0 _PAGE_SIZE=15
    while IFS= read -r _line; do
        [[ -n "$_line" ]] && _ZONES+=("$_line")
    done < <(_mv_tz_list)
    _total=${#_ZONES[@]}
    [[ $_total -eq 0 ]] && { echo -e "${YELLOW}   ⚠ No se pudo obtener la lista de zonas horarias.${RESET}"; return 1; }

    while true; do
        # Aplicar filtro de búsqueda
        _VIEW=()
        for _i in "${_ZONES[@]}"; do
            if [[ -z "$_filter" || "$_i" == *"$_filter"* ]]; then _VIEW+=("$_i"); fi
        done
        _vtot=${#_VIEW[@]}
        [[ $_vtot -eq 0 ]] && { echo -e "${YELLOW}   ⚠ Sin resultados para '$_filter'.${RESET}"; _filter=""; continue; }
        # Ajustar página si quedó fuera de rango
        (( _page * _PAGE_SIZE >= _vtot )) && _page=$(( (_vtot - 1) / _PAGE_SIZE ))
        _from=$(( _page * _PAGE_SIZE ))
        _to=$(( _from + _PAGE_SIZE ))
        (( _to > _vtot )) && _to=$_vtot

        clear
        echo -e "${_ci3}   ╔════════════════════════════════════════════════╗${_rs3}"
        echo -e "${_ci3}   ║${_go3}      🌍 ZONAS HORARIAS DEL MUNDO (${_am3}${_vtot}${_go3}) ${_ci3}       ║${_rs3}"
        echo -e "${_ci3}   ║${_bl3}  Página ${_am3}$(( _page + 1 ))/$(( (_vtot - 1) / _PAGE_SIZE + 1 ))${_bl3} · ${_go3}$(( _from + 1 ))-${_to}${_bl3} de ${_am3}${_vtot}${_rs3}${_ci3}        ║${_rs3}"
        if [[ -n "$_filter" ]]; then
            echo -e "${_ci3}   ║${_go3}  🔎 Buscando: ${_bl3}$_filter${_rs3}${_ci3}                    ║${_rs3}"
        fi
        echo -e "${_ci3}   ╠════════════════════════════════════════════════╣${_rs3}"
        for (( _i = _from; _i < _to; _i++ )); do
            printf "${_ci3}   ║ ${_am3}%3d)${_rs3}  ${_bl3}%-33s${_rs3}${_ci3}║${_rs3}\n" $(( _i - _from + 1 )) "${_VIEW[$_i]}"
        done
        echo -e "${_ci3}   ╠════════════════════════════════════════════════╣${_rs3}"
        echo -e "${_ci3}   ║${_go3}  [n]${_bl3}Siguiente${_rs3}${_ci3}  ${_go3}[p]${_bl3}Anterior${_rs3}${_ci3}  ${_go3}[b]${_bl3}Buscar${_rs3}${_ci3}  ${_go3}[0]${_bl3}Cancelar${_rs3}${_ci3}   ║${_rs3}"
        echo -e "${_ci3}   ╚════════════════════════════════════════════════╝${_rs3}"
        read -rp "$(echo -e "${_ci3}➤ ${_bl3}Elige el número de tu zona horaria ${_go3}(Enter = siguiente)${_rs3} ➤ ")" _cmd
        if [[ "$_cmd" =~ ^[0-9]+$ ]]; then
            if (( _cmd >= 1 && _cmd <= _to - _from )); then
                _sel="${_VIEW[$(( _from + _cmd - 1 ))]}"
                WELCOME_TZ="$_sel"
                return 0
            fi
        fi
        case "$_cmd" in
            n|N|"") (( _page++ )) ;;
            p|P)    (( _page-- )); (( _page < 0 )) && _page=0 ;;
            b|B)    read -rp "$(echo -e "${_ci3}➤ ${_bl3}Filtrar zona ${_go3}(ej: Lima, Bogota, UTC)${_rs3} ➤ ")" _filter ;;
            0|q|Q)  WELCOME_TZ=""; return 0 ;;
        esac
    done
}

# ── 3) Zona horaria (opcional, timedatectl) ──
if [[ -t 0 && "$AUTO_INSTALL" == "0" ]]; then
    echo ""
    echo -e "${_ci3}   ╔════════════════════════════════════════════════╗${_rs3}"
    echo -e "${_ci3}   ║${_go3}        🕒 CONFIGURACIÓN DE ZONA HORARIA${_rs3}${_ci3}          ║${_rs3}"
    echo -e "${_ci3}   ╠════════════════════════════════════════════════╣${_rs3}"
    echo -e "${_ci3}   ║${_bl3}  Actual : ${_go3}$(cat /etc/timezone 2>/dev/null || timedatectl show -p Timezone --value 2>/dev/null || echo "UTC")${_rs3}${_ci3}          ║${_rs3}"
    echo -e "${_ci3}   ║${_bl3}  ¿Deseas cambiar la zona horaria?${_rs3}${_ci3}            ║${_rs3}"
    echo -e "${_ci3}   ║${_am3}  [1] ${_bl3}Sí, configurar${_rs3}${_ci3}   [2] ${_bl3}No, mantener${_rs3}${_ci3}  ║${_rs3}"
    echo -e "${_ci3}   ╚════════════════════════════════════════════════╝${_rs3}"
    read -rp "$(echo -e "${_ci3}➤ ${_bl3}Opción [1-2] ${_go3}(por defecto: 2=No)${_rs3} ➤ ")" WELCOME_TZ_CHOICE
    if [[ "${WELCOME_TZ_CHOICE:-2}" == "1" ]]; then
        _mv_tz_pick
        if [[ -n "$WELCOME_TZ" ]] && command -v timedatectl >/dev/null 2>&1; then
            timedatectl set-timezone "$WELCOME_TZ" 2>/dev/null \
                && echo -e "${GREEN}   ✔ Zona horaria configurada: ${WHITE}${WELCOME_TZ}${RESET}" \
                || echo -e "${YELLOW}   ⚠ No se pudo aplicar; seguimos con la actual.${RESET}"
        elif [[ -n "$WELCOME_TZ" ]]; then
            ln -sf "/usr/share/zoneinfo/$WELCOME_TZ" /etc/localtime 2>/dev/null \
                && echo -e "${GREEN}   ✔ Zona horaria configurada: ${WHITE}${WELCOME_TZ}${RESET}"
        fi
    fi
fi

# ── Confirmación final ──
# AUTO_INSTALL: aplicar defaults (plan REAL key, ×20, versión ESTABLE,
# zona horaria actual) si las variables quedaron vacías.
if [[ "$AUTO_INSTALL" == "1" ]]; then
    [[ -z "$WELCOME_PLAN" ]]        && WELCOME_PLAN="${FB_REAL_PLAN:-premium}"
    [[ -z "$WELCOME_PLAN_COSTO" ]]  && WELCOME_PLAN_COSTO="20"
    [[ -z "$WELCOME_VERSION" ]]     && WELCOME_VERSION="stable"
fi
echo ""
echo -e "${_ci3}   ╔════════════════════════════════════════════════╗${_rs3}"
echo -e "${_ci3}   ║${_go3}        ✅ CONFIRMACIÓN DE INSTALACIÓN${_rs3}${_ci3}        ║${_rs3}"
echo -e "${_ci3}   ╠════════════════════════════════════════════════╣${_rs3}"
echo -e "${_ci3}   ║${_bl3}  Plan        : ${_am3}${WELCOME_PLAN^^} ${_go3}${WELCOME_PLAN_COSTO} USDT${_rs3}${_ci3}        ║${_rs3}"
echo -e "${_ci3}   ║${_bl3}  Versión     : ${_am3}${WELCOME_VERSION^^}${_rs3}${_ci3}                    ║${_rs3}"
echo -e "${_ci3}   ║${_bl3}  Zona horaria: ${_am3}${WELCOME_TZ:-Actual}${_rs3}${_ci3}                 ║${_rs3}"
echo -e "${_ci3}   ╚════════════════════════════════════════════════╝${_rs3}"
echo ""
# AUTO_INSTALL: confirmación implícita (sí)
WELCOME_GO="s"
if [[ -t 0 && "$AUTO_INSTALL" == "0" ]]; then
    read -rp "$(echo -e "${_ci3}➤ ${_bl3}¿Comenzar la instalación? [Enter = sí / n = cancelar] ${_rs3}")" WELCOME_GO
    if [[ "${WELCOME_GO:-s}" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Instalación cancelada por el usuario.${RESET}"
        exit 0
    fi
fi
unset _az3 _ci3 _go3 _am3 _mg3 _na3 _bl3 _rs3
sleep 1

# ═══════════════════════════════════════════════════════════════
# BACKUP + LIMPIEZA TOTAL DE VPS
# ═══════════════════════════════════════════════════════════════

# Detectar usuarios existentes (UID >= 1000, no-root/no-nobody)
EXISTING_USERS=()
EXISTING_PASS=()
for u in $(awk -F: '$3>=1000 && $1!="nobody"{print $1}' /etc/passwd 2>/dev/null); do
    EXISTING_USERS+=("$u")
done

if [[ ${#EXISTING_USERS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${GOLD}         🔄 SISTEMA DETECTADO — LIMPIEZA TOTAL${RESET}${CYAN}          ║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${WHITE}  Se encontraron ${GREEN}${#EXISTING_USERS[@]}${WHITE} usuarios en el sistema:${RESET}${CYAN}       ║${RESET}"
    for u in "${EXISTING_USERS[@]}"; do
        echo -e "${CYAN}║${WHITE}     • ${u}${RESET}${CYAN}                                            ║${RESET}"
    done
    echo -e "${CYAN}║${WHITE}                                                            ${RESET}${CYAN}║${RESET}"
    echo -e "${CYAN}║${YELLOW}  Se hará backup y se limpiará TODO para reinstalación.${RESET}${CYAN}  ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""

    # ── BACKUP: guardar usuario:password ──
    echo -e "${CYAN}   [1/4] 📦 Creando backup de usuarios...${RESET}"

    BACKUP_FILE="/tmp/movivip-users-backup.txt"
    BACKUP_PASSWD="/tmp/movivip-backup-passwd.txt"
    BACKUP_SHADOW="/tmp/movivip-backup-shadow.txt"
    > "$BACKUP_FILE"

    # Guardar passwd y shadow completos para restauración fiel
    cp /etc/passwd "$BACKUP_PASSWD"
    cp /etc/shadow "$BACKUP_SHADOW"

    # También extraer user:pass en formato legible (para referencia)
    for u in "${EXISTING_USERS[@]}"; do
        # Obtener hash del shadow
        HASH=$(awk -F: -v user="$u" '$1==user{print $2}' /etc/shadow 2>/dev/null)
        EXPIRY=$(chage -l "$u" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
        [[ "$EXPIRY" == "never" ]] && EXPIRY="0"
        echo "${u}:${HASH}:${EXPIRY}" >> "$BACKUP_FILE"
    done

    echo -e "${GREEN}      ✔ Backup guardado: $BACKUP_FILE (${#EXISTING_USERS[@]} usuarios)${RESET}"
    echo ""

    # ── PREGUNTAR: ¿Eliminar algún usuario? ──
    echo -e "${CYAN}   [2/4] 🗑️  ¿Eliminar algún usuario permanentemente?${RESET}"
    echo -e "${CYAN}   (los eliminados NO se restaurarán después de la limpieza)${RESET}"
    echo ""
    for i in "${!EXISTING_USERS[@]}"; do
        echo -e "      ${WHITE}[$((i+1))]${RESET} ${EXISTING_USERS[$i]}"
    done
    echo -e "      ${GREEN}[0]${RESET} No eliminar ninguno (restaurar todos)"
    echo ""

    if [[ -t 0 && "$AUTO_INSTALL" == "0" ]]; then
        read -rp "$(echo -e "${CYAN}   Números a eliminar (ej: 1 3) ➤ ${RESET}")" DELETE_CHOICE
    else
        DELETE_CHOICE="${DELETE_CHOICE:-0}"
    fi
    DELETE_CHOICE="${DELETE_CHOICE:-0}"
    # Validar que solo contenga números y espacios
    [[ "$DELETE_CHOICE" =~ ^[0-9\ ]+$ ]] || DELETE_CHOICE=0

    # Eliminar usuarios seleccionados
    DELETED_USERS=()
    if [[ "$DELETE_CHOICE" != "0" ]]; then
        for num in $DELETE_CHOICE; do
            idx=$((num - 1))
            if [[ $idx -ge 0 && $idx -lt ${#EXISTING_USERS[@]} ]]; then
                DEL_USER="${EXISTING_USERS[$idx]}"
                userdel -f "$DEL_USER" &>/dev/null
                DELETED_USERS+=("$DEL_USER")
                echo -e "${RED}      ✖ Eliminado: $DEL_USER${RESET}"
                # Quitar del backup
                sed -i "/^${DEL_USER}:/d" "$BACKUP_FILE" 2>/dev/null
            fi
        done
    fi

    if [[ ${#DELETED_USERS[@]} -gt 0 ]]; then
        echo -e "${GREEN}      ✔ ${#DELETED_USERS[@]} usuarios eliminados permanentemente${RESET}"
    else
        echo -e "${GREEN}      ✔ Ningún usuario eliminado — todos se restaurarán${RESET}"
    fi
    echo ""

    # ── LIMPIEZA TOTAL ──
    echo -e "${CYAN}   [3/4] 🧹 Limpiando TODO el sistema anterior...${RESET}"

    # Detener TODOS los servicios VPN/Proxy
    echo -e "${CYAN}      → Deteniendo servicios VPN/Proxy...${RESET}"
    for svc in xray v2ray dropbear dropbear_custom badvpn-udpgw udpcustom \
               squid webmin openvpn slowdns dnstt-server ssh-ws-internal hcr; do
        systemctl stop "$svc" 2>/dev/null
        systemctl disable "$svc" 2>/dev/null
    done

    # Matar procesos sueltos
    killall -9 xray v2ray dropbear badvpn-udpgw squid dnstt-server 2>/dev/null || true

    # Eliminar configuraciones de servicios
    echo -e "${CYAN}      → Eliminando configuraciones de servicios...${RESET}"
    # Preservar usuarios ZipVPN + Xray antes de limpiar (FIX v6.5)
    preservar_usuarios_vpn
    rm -rf /etc/xray
    rm -rf /usr/local/etc/xray
    rm -rf /usr/local/share/xray
    rm -f /usr/bin/xray /usr/local/bin/xray
    rm -f /usr/local/etc/v2ray
    rm -rf /etc/v2ray
    rm -f /etc/systemd/system/xray*.service
    rm -f /etc/systemd/system/v2ray*.service
    rm -f /etc/systemd/system/dropbear*.service
    rm -f /etc/systemd/system/badvpn*.service
    rm -f /etc/systemd/system/udpcustom*.service
    rm -f /etc/systemd/system/slowdns*.service
    rm -f /etc/systemd/system/ssh-ws*.service
    rm -f /etc/systemd/system/movivip*.service
    systemctl daemon-reload 2>/dev/null

    # Eliminar binarios de servicios
    rm -f /usr/bin/dropbear
    rm -f /usr/sbin/dropbear
    rm -f /usr/bin/badvpn-udpgw
    rm -f /usr/bin/udp
    rm -f /usr/bin/config.json
    rm -rf /usr/local/SlowDNS
    rm -rf /tmp/dnstt*

    # Eliminar configuraciones de red
    echo -e "${CYAN}      → Eliminando configuraciones de red...${RESET}"
    rm -f /etc/sysctl.d/99-z-MoviVIP.conf
    rm -f /etc/sysctl.d/99-movivip.conf
    rm -f /etc/iptables/rules.v4
    # Restaurar sysctl por defecto
    cat > /etc/sysctl.d/99-default.conf << 'SYSCTLEOF'
net.ipv4.ip_forward=0
net.core.default_qdisc=pfifo_fast
net.ipv4.tcp_congestion_control=cubic
net.ipv4.ip_local_port_range=32768 60999
net.ipv4.tcp_fin_timeout=60
net.ipv4.tcp_keepalive_time=7200
net.ipv4.tcp_tw_reuse=0
net.ipv4.tcp_timestamps=1
net.core.somaxconn=4096
net.core.netdev_max_backlog=1000
net.ipv4.tcp_max_syn_backlog=1024
net.ipv4.tcp_slow_start_after_idle=1
net.ipv4.tcp_mtu_probing=0
vm.swappiness=60
fs.file-max=2097152
SYSCTLEOF
    sysctl --system >/dev/null 2>&1

    # Limpiar iptables
    echo -e "${CYAN}      → Limpiando reglas iptables...${RESET}"
    iptables -F 2>/dev/null
    iptables -X 2>/dev/null
    iptables -t nat -F 2>/dev/null
    iptables -t nat -X 2>/dev/null
    iptables -t mangle -F 2>/dev/null
    iptables -t mangle -X 2>/dev/null
    iptables -t raw -F 2>/dev/null
    iptables -t raw -X 2>/dev/null
    iptables -P INPUT ACCEPT 2>/dev/null
    iptables -P FORWARD ACCEPT 2>/dev/null
    iptables -P OUTPUT ACCEPT 2>/dev/null
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

    # Eliminar crons de movivip
    echo -e "${CYAN}      → Limpiando crons...${RESET}"
    crontab -l 2>/dev/null | grep -v "movivip\|auto-cleanup\|auto-update\|network_snapshot\|online.sh" | crontab - 2>/dev/null

    # Eliminar /etc/movivip temporalmente (se recreará)
    rm -rf /etc/movivip

    # Eliminar banners
    rm -f /etc/profile.d/MoviVIP-banner.sh
    rm -f /etc/issue.net

    # Eliminar limpiezas temporales
    rm -f /tmp/movivip-*.sh /tmp/validar-licencia*.sh

    # Eliminar scripts de otros sistemas VPN
    rm -f /usr/local/bin/menu

    echo -e "${GREEN}      ✔ Sistema limpiado completamente${RESET}"
    echo ""

    # ── RESTAURAR USUARIOS ──
    echo -e "${CYAN}   [4/4] 👥 Restaurando usuarios supervivientes...${RESET}"

    REMAINING=()
    for u in "${EXISTING_USERS[@]}"; do
        # Saltar eliminados
        skip=false
        for d in "${DELETED_USERS[@]}"; do
            [[ "$u" == "$d" ]] && skip=true && break
        done
        $skip && continue

        # Leer datos del backup
        HASH=$(awk -F: -v user="$u" '$1==user{print $2}' "$BACKUP_FILE" 2>/dev/null)
        EXPIRY=$(awk -F: -v user="$u" '$1==user{print $3}' "$BACKUP_FILE" 2>/dev/null)

        # Crear usuario
        if [[ -n "$EXPIRY" && "$EXPIRY" != "0" ]]; then
            useradd -e "$EXPIRY" -M -s /usr/sbin/nologin "$u" 2>/dev/null
        else
            useradd -M -s /usr/sbin/nologin "$u" 2>/dev/null
        fi

        # Restaurar password desde shadow
        if [[ -n "$HASH" && "$HASH" != "!" && "$HASH" != "*" ]]; then
            echo "${u}:${HASH}" | chpasswd -e 2>/dev/null
        fi

        REMAINING+=("$u")
        echo -e "${GREEN}      ✔ Restaurado: $u${RESET}"
    done

    echo ""

    # Restaurar licencia de /tmp si existe
    if [[ -f /tmp/movivip-key.txt ]]; then
        mkdir -p /etc/movivip
    fi

    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${GREEN}            ✅ LIMPIEZA COMPLETADA${RESET}${CYAN}                       ║${RESET}"
    echo -e "${CYAN}║${WHITE}  Usuarios restaurados: ${GREEN}${#REMAINING[@]}${RESET}${CYAN}                            ║${RESET}"
    echo -e "${CYAN}║${WHITE}  Usuarios eliminados:  ${RED}${#DELETED_USERS[@]}${RESET}${CYAN}                            ║${RESET}"
    echo -e "${CYAN}║${WHITE}  Sistema: LIMPIO — listo para instalación nueva${RESET}${CYAN}   ║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    sleep 2
else
    echo ""
    echo -e "${GREEN}   ✔ Sistema limpio — primera instalación (no hay usuarios previos)${RESET}"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════
# INSTALAR PAQUETES BÁSICOS
# ═══════════════════════════════════════════════════════════════

step "Actualizando repositorios..."
run_cmd "Actualizando repositorios" "$LINENO" "pkg_update"

step "Instalando paquetes esenciales..."
# Habilitar EPEL en RHEL/Oracle/Rocky/Alma para fail2ban y otros
if [[ "$PKG" == "dnf" ]]; then
    run_cmd "Habilitando repositorio EPEL" "$LINENO" "dnf install -y epel-release 2>/dev/null || dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel 2>/dev/null || echo 9).noarch.rpm 2>/dev/null"
fi
# Paquetes comunes a todas las distros
COMMON_PKGS="curl wget git unzip zip tar sudo nano lsof screen jq bc socat openssl ca-certificates iptables iproute2 less whois net-tools"
# Nombres que cambian por distro
case "$PKG" in
    apt)    EXTRA_PKGS="dnsutils cron fail2ban" ;;
    dnf)    EXTRA_PKGS="bind-utils cronie fail2ban ipset" ;;
    zypper) EXTRA_PKGS="bind-utils cron cronie fail2ban" ;;
    pacman) EXTRA_PKGS="bind net-tools cronie fail2ban" ;;
esac
run_cmd "Paquetes esenciales" "$LINENO" "pkg_install $COMMON_PKGS $EXTRA_PKGS"

# ═══════════════════════════════════════════════════════════════
# SSL/TLS + HAPROXY — INSTALACIÓN AUTOMÁTICA
# ═══════════════════════════════════════════════════════════════

step "Instalando SSL/TLS + HAProxy..."

run_cmd "Instalando haproxy" "$LINENO" "pkg_install haproxy python3"

if [[ ! -f /etc/haproxy/yha.pem ]]; then
    SSL_DOMAIN=$(hostname -f 2>/dev/null || echo 'ssl-tunnel')
    SSL_IP=$(curl -s4 ifconfig.me 2>/dev/null || echo '127.0.0.1')
    cat > /tmp/openssl-movivip.cnf << EOFCNF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[dn]
C = CO
ST = Bogota
L = Bogota
O = MoviVIP Network
OU = VPN
CN = ${SSL_DOMAIN}

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${SSL_DOMAIN}
DNS.2 = *.${SSL_DOMAIN}
DNS.3 = ${SSL_DOMAIN#*.}
IP.1 = ${SSL_IP}
EOFCNF
    run_cmd "Generando certificado SSL autofirmado con SAN" "$LINENO" "openssl req -x509 -nodes -newkey rsa:2048 -days 3650 -keyout /tmp/key.pem -out /tmp/cert.pem -config /tmp/openssl-movivip.cnf 2>/dev/null && cat /tmp/key.pem /tmp/cert.pem > /etc/haproxy/yha.pem && chmod 600 /etc/haproxy/yha.pem && rm -f /tmp/key.pem /tmp/cert.pem /tmp/openssl-movivip.cnf"
    mkdir -p /etc/ssl/movivip /usr/local/etc/xray
    cp /etc/haproxy/yha.pem /etc/ssl/movivip/server.pem 2>/dev/null
    openssl rsa -in /etc/haproxy/yha.pem -out /etc/ssl/movivip/server.key 2>/dev/null
    cp /etc/haproxy/yha.pem /usr/local/etc/xray/server.crt 2>/dev/null || true
    openssl rsa -in /etc/haproxy/yha.pem -out /usr/local/etc/xray/server.key 2>/dev/null || true
    chmod 600 /usr/local/etc/xray/server.key 2>/dev/null || true
fi

# Fallback robusto: si por cualquier motivo no quedó el .pem, generar uno simple
if [[ ! -s /etc/haproxy/yha.pem ]]; then
    echo -e "      ${YELLOW}⚠${RESET} Usando certificado simple (fallback SAN no disponible)"
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /tmp/yha.key -out /tmp/yha.crt -subj '/CN=ssl-tunnel' >/dev/null 2>&1
    cat /tmp/yha.key /tmp/yha.crt > /etc/haproxy/yha.pem
    chmod 600 /etc/haproxy/yha.pem
    rm -f /tmp/yha.key /tmp/yha.crt
fi

for P in 80 443 8080 8443; do
    fuser -k "$P/tcp" >/dev/null 2>&1
done

# ssh-ws-internal.py (WebSocket → SSH)
if [[ ! -f /usr/local/bin/ssh-ws-internal.py ]]; then
    cat > /usr/local/bin/ssh-ws-internal.py << 'PYEOF'
#!/usr/bin/env python3
import asyncio, signal, sys
BUFFER_SIZE = 65536
SSH_HOST = "127.0.0.1"
SSH_PORT = 22
R101 = b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
R200 = b"HTTP/1.1 200 Connection established\r\n\r\n"
active = 0

async def pipe(r, w):
    try:
        while True:
            d = await r.read(BUFFER_SIZE)
            if not d: break
            w.write(d); await w.drain()
    except: pass
    finally:
        try: w.close()
        except: pass

async def handle(cr, cw):
    global active
    active += 1; sw = None
    try:
        try:
            p = await asyncio.wait_for(cr.read(BUFFER_SIZE), timeout=10)
        except asyncio.TimeoutError:
            cw.close(); active -= 1; return
        if not p:
            cw.close(); active -= 1; return
        req = p.decode("utf-8", errors="ignore").upper()
        cw.write(R101 if ("UPGRADE" in req or "WEBSOCKET" in req) else R200)
        await cw.drain()
        try:
            sr, sw = await asyncio.open_connection(SSH_HOST, SSH_PORT)
        except:
            cw.close(); active -= 1; return
        await asyncio.gather(pipe(cr, sw), pipe(sr, cw))
    except: pass
    finally:
        active -= 1
        try: cw.close()
        except: pass
        if sw:
            try: sw.close()
            except: pass

async def start(port):
    s = await asyncio.start_server(handle, "127.0.0.1", port)
    async with s: await s.serve_forever()

def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 10015
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    for sig in (signal.SIGTERM, signal.SIGINT):
        try: loop.add_signal_handler(sig, lambda: loop.stop())
        except: pass
    loop.run_until_complete(start(port))

if __name__ == "__main__":
    main()
PYEOF
    run_cmd "Estableciendo permisos ssh-ws-internal" "$LINENO" "chmod +x /usr/local/bin/ssh-ws-internal.py"
fi

cat > /etc/systemd/system/ssh-ws-internal.service << 'SVCEOF'
[Unit]
Description=SSH WebSocket Internal (127.0.0.1:10015)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ssh-ws-internal.py 10015
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SVCEOF

mkdir -p /etc/haproxy
cat > /etc/haproxy/haproxy.cfg << 'HAPCFG'
global
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 1d
    tune.bufsize 1048576
    tune.maxrewrite 3072
    tune.ssl.default-dh-param 2048
    pidfile /run/haproxy.pid
    chroot /var/lib/haproxy
    user haproxy
    group haproxy
    daemon
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private

defaults
    log global
    mode tcp
    option dontlognull
    option tcp-smart-connect
    timeout connect 5s
    timeout client 24h
    timeout server 24h

frontend multiport_frontend
    mode tcp
    bind *:443 tfo
    tcp-request inspect-delay 10ms
    tcp-request content accept if HTTP
    tcp-request content accept if { req.ssl_hello_type 1 }
    use_backend recir_http_backend if HTTP
    default_backend recir_https_backend

backend recir_https_backend
    mode tcp
    server recir_https_server abns@haproxy-https send-proxy-v2 check

backend recir_http_backend
    mode tcp
    server recir_http_server abns@haproxy-http send-proxy-v2 check

frontend multiports_frontend
    mode tcp
    bind abns@haproxy-http accept-proxy tfo
    default_backend recir_https_www_backend

backend recir_https_www_backend
    mode tcp
    server recir_https_www_server 127.0.0.1:2223 check

frontend ssl_frontend
    mode tcp
    bind *:80 tfo
    bind *:8080 tfo
    bind *:8443 ssl crt /etc/haproxy/yha.pem alpn h2,http/1.1 tfo
    bind abns@haproxy-https accept-proxy ssl crt /etc/haproxy/yha.pem alpn h2,http/1.1 tfo
    tcp-request inspect-delay 200ms
    tcp-request content capture req.ssl_sni len 100
    tcp-request content accept if { req.ssl_hello_type 1 }
    acl acl_upgrade hdr(Connection) -i upgrade
    acl acl_websocket hdr(Upgrade) -i websocket
    acl acl_payload payload(0,7) -m bin 5353482d322e30
    acl acl_http2 ssl_fc_alpn -i h2
    acl acl_path_regex path_reg -i ^\/(.*)
    acl acl_path_vless path_reg -i ^\/vless.*
    acl acl_path_vmess path_reg -i ^\/vmess.*
    acl acl_path_trojan path_reg -i ^\/trojan-ws.*
    acl acl_path_grpc path_reg -i ^\/(vmess-grpc|trojan-grpc|ss-grpc).*
    acl acl_path_ssh path_reg -i ^\/fightertunnelssh.*
    use_backend grpc_backend if acl_http2
    use_backend vmess_backend if acl_path_vless
    use_backend vmess_backend if acl_path_vmess
    use_backend vmess_backend if acl_path_trojan
    use_backend vmess_backend if acl_path_grpc
    use_backend ssh_backend if acl_path_ssh
    use_backend websocket_backend if acl_upgrade acl_websocket
    use_backend websocket_backend if acl_path_regex
    use_backend bot_ftvpn_backend if acl_payload
    default_backend ssh_ws_default_backend

backend websocket_backend
    mode tcp
    server ssh_ws_server 127.0.0.1:10015 check

backend grpc_backend
    mode tcp
    server grpc_server 127.0.0.1:10015 check

backend ssh_ws_default_backend
    mode tcp
    server ssh_ws_server 127.0.0.1:10015 check

backend bot_ftvpn_backend
    mode tcp
    server ssh_direct 127.0.0.1:22 check

backend vmess_backend
    mode tcp
    server payload_server_vmess   127.0.0.1:10002 check

backend ssh_backend
    mode tcp
    server ssh_server 127.0.0.1:10015 check
HAPCFG

run_cmd "Configurando resiliencia HAProxy" "$LINENO" "mkdir -p /etc/systemd/system/haproxy.service.d"
cat > /etc/systemd/system/haproxy.service.d/10-resilience.conf << 'RESF'
[Unit]
After=network-online.target ssh-ws-internal.service
Wants=network-online.target ssh-ws-internal.service

[Service]
Restart=always
RestartSec=3
StartLimitIntervalSec=0
ExecStartPre=/bin/mkdir -p /run/haproxy
ExecStartPre=/bin/mkdir -p /var/lib/haproxy
ExecStartPre=/bin/chown -R haproxy:haproxy /var/lib/haproxy /run/haproxy
RESF

HAPROXY_CHECK=$(haproxy -c -f /etc/haproxy/haproxy.cfg 2>&1)
if [[ $? -eq 0 ]]; then
    run_cmd "Recargando systemd" "$LINENO" "systemctl daemon-reload"
    run_cmd "Habilitando haproxy + ssh-ws-internal" "$LINENO" "systemctl enable haproxy ssh-ws-internal"
    run_cmd "Iniciando servicios" "$LINENO" "systemctl restart ssh-ws-internal haproxy"
    echo -e "      ${GREEN}✔${RESET} SSL/TLS + HAProxy instalado y activo"
else
    echo -e "      ${RED}✖${RESET} HAProxy configuración con errores — Reportar a soporte: línea $LINENO"
    echo -e "      ${GRAY}  → ${HAPROXY_CHECK}${RESET}"
    log_error "$LINENO" "HAProxy config validation" "haproxy -c" "$HAPROXY_CHECK"
fi

# ═══════════════════════════════════════════════════════════════
# STUNNEL4 — SSL Tunnel para SSH
# ═══════════════════════════════════════════════════════════════

step "Instalando stunnel4..."

if ! command -v stunnel4 &>/dev/null && ! command -v stunnel &>/dev/null; then
    run_cmd "Instalando stunnel4" "$LINENO" "pkg_install stunnel4"
fi

STUNNEL_PEM="/etc/stunnel/stunnel.pem"
STUNNEL_CONF="/etc/stunnel/stunnel.conf"

mkdir -p /etc/stunnel

if [[ ! -f "$STUNNEL_PEM" ]]; then
    run_cmd "Generando certificado stunnel" "$LINENO" "
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
            -keyout /etc/stunnel/stunnel.key -out /etc/stunnel/stunnel.crt \
            -subj '/CN=stunnel/O=MoviVIP' 2>/dev/null
        cat /etc/stunnel/stunnel.crt /etc/stunnel/stunnel.key > $STUNNEL_PEM
        chmod 600 $STUNNEL_PEM
    "
fi

if [[ ! -f "$STUNNEL_CONF" ]]; then
    cat > "$STUNNEL_CONF" << 'STEOF'
pid = /run/stunnel4/stunnel.pid
setuid = stunnel4
setgid = stunnel4

[ssh-dropbear]
    accept = 0.0.0.0:445
    connect = 127.0.0.1:109
    cert = /etc/stunnel/stunnel.pem

[ssh-dropbear2]
    accept = 0.0.0.0:844
    connect = 127.0.0.1:143
    cert = /etc/stunnel/stunnel.pem

[ssh-dropbear3]
    accept = 0.0.0.0:444
    connect = 127.0.0.1:90
    cert = /etc/stunnel/stunnel.pem
STEOF
fi

run_cmd "Configurando directorio stunnel" "$LINENO" "mkdir -p /run/stunnel4 && chown stunnel4:stunnel4 /run/stunnel4"
run_cmd "Habilitando stunnel4" "$LINENO" "systemctl enable stunnel4"
run_cmd "Iniciando stunnel4" "$LINENO" "systemctl restart stunnel4"

if systemctl is-active --quiet stunnel4; then
    echo -e "      ${GREEN}✔${RESET} stunnel4 activo (puertos 445, 844, 444)"
else
    echo -e "      ${YELLOW}⚠${RESET} stunnel4 no pudo iniciar (no crítico)"
fi

# ═══════════════════════════════════════════════════════════════
# AUTO-SIGN — Script para dominios nuevos
# ═══════════════════════════════════════════════════════════════

if [[ ! -f /usr/local/bin/auto-sign-domain ]]; then
    cat > /usr/local/bin/auto-sign-domain << 'AUTOEOF'
#!/bin/bash
# Auto-sign SSL certificate for a new domain
# Usage: auto-sign-domain <domain> [ip]
DOMAIN="${1:-}"
IP="${2:-$(curl -s4 ifconfig.me 2>/dev/null || echo '127.0.0.1')}"
CERT_DIR="/etc/ssl/movivip"
HAPROXY_CERT="/etc/haproxy/yha.pem"
if [ -z "$DOMAIN" ]; then
    echo "$(trx 'Uso: auto-sign-domain <dominio> [ip]')"
    exit 1
fi
echo "Auto-signing certificate for: $DOMAIN"
cat > /tmp/openssl_${DOMAIN}.cnf << EOFCNF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req
[dn]
C = CO
ST = Bogota
L = Bogota
O = MoviVIP Network
OU = VPN
CN = ${DOMAIN}
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
DNS.3 = ${DOMAIN#*.}
IP.1 = ${IP}
EOFCNF
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout "${CERT_DIR}/${DOMAIN}.key" \
    -out "${CERT_DIR}/${DOMAIN}.crt" \
    -config /tmp/openssl_${DOMAIN}.cnf 2>/dev/null
cat "${CERT_DIR}/${DOMAIN}.crt" "${CERT_DIR}/${DOMAIN}.key" >> "$HAPROXY_CERT"
chmod 600 "$HAPROXY_CERT"
cp "${CERT_DIR}/${DOMAIN}.crt" /usr/local/etc/xray/ 2>/dev/null
cp "${CERT_DIR}/${DOMAIN}.key" /usr/local/etc/xray/ 2>/dev/null
systemctl reload haproxy 2>/dev/null || systemctl restart haproxy
echo "OK: Certificate generated for $DOMAIN"
AUTOEOF
    chmod +x /usr/local/bin/auto-sign-domain
fi

# ═══════════════════════════════════════════════════════════════
# FIREWALL — Abrir puertos UDP para Xray + stunnel
# ═══════════════════════════════════════════════════════════════

step "Configurando firewall UDP..."

for port in 6954 2958 34778 28648 46079 25609 53899 45768 19147 41175 19195; do
    iptables -C INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null \
        || iptables -I INPUT 6 -p udp --dport "$port" -j ACCEPT 2>/dev/null
done

for port in 445 844 444; do
    iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null \
        || iptables -I INPUT 5 -p tcp --dport "$port" -j ACCEPT 2>/dev/null
done

echo -e "      ${GREEN}✔${RESET} Puertos UDP y stunnel abiertos en firewall"

#==============================
# 🚀 MOVIVIP — OPTIMIZADOR EXTREMO (AUTO)
#==============================

BW=$(tput cols 2>/dev/null || echo 60)
[[ "$BW" =~ ^[0-9]+$ ]] || BW=60
(( BW < 30 )) && BW=30
(( BW > 60 )) && BW=60
echo ""
echo -e "${CYAN}╔$(printf '═%.0s' $(seq 1 $((BW-2))))╗${RESET}"
echo -e "${CYAN}║${RESET}${GOLD}   🚀 MOVIVIP — OPTIMIZADOR EXTREMO 🚀${RESET}${CYAN}   ║${RESET}"
if (( BW >= 58 )); then
    echo -e "${CYAN}╠$(printf '═%.0s' $(seq 1 $((BW-2))))╣${RESET}"
    echo -e "${CYAN}║${RESET}${WHITE}   Mantén tu VPS como una pluma 🪶 aunque tengas muchos usuario${RESET}${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}${WHITE}   [1] 🧹 Limpiar recursos  (RAM/caché/swap/logs/procesos)    ${RESET}${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}${WHITE}   [2] 🚀 Optimizar red     (BBR+FQ+MTU1470+buffers64MB)      ${RESET}${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}${WHITE}   [3] ⏰ Limpieza automática (cada X tiempo)                ${RESET}${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}${WHITE}   [4] ⚙️ Editar valores de red (buffers/MTU/swappiness)    ${RESET}${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}${WHITE}   [5] 📊 Ver recursos      (RAM/CPU/procesos top)          ${RESET}${CYAN}║${RESET}"
else
    echo -e "${CYAN}╠$(printf '═%.0s' $(seq 1 $((BW-2))))╣${RESET}"
    echo -e "${CYAN}║${RESET}${WHITE}   Mantén tu VPS como una pluma 🪶  ${RESET}${CYAN}║${RESET}"
    echo -e "${CYAN}║${RESET}${WHITE}   [1] 🧹 Limpiar recursos  ${RESET}${CYAN}       ║${RESET}"
    echo -e "${CYAN}║${RESET}${WHITE}   [2] 🚀 Optimizar red     ${RESET}${CYAN}       ║${RESET}"
    echo -e "${CYAN}║${RESET}${WHITE}   [3] ⏰ Limpieza automática ${RESET}${CYAN}      ║${RESET}"
    echo -e "${CYAN}║${RESET}${WHITE}   [4] ⚙️ Editar valores red ${RESET}${CYAN}       ║${RESET}"
    echo -e "${CYAN}║${RESET}${WHITE}   [5] 📊 Ver recursos      ${RESET}${CYAN}       ║${RESET}"
fi
echo -e "${CYAN}╚$(printf '═%.0s' $(seq 1 $((BW-2))))╝${RESET}"
echo ""
echo -e "${CYAN}   → ${GOLD}Instalación automática: Optimizando todo...${RESET}"
echo ""

step "Optimizando recursos del sistema..."

run_cmd "Limpiando caché de paquetes" "$LINENO" "pkg_clean"

# Paquetes críticos — proteger contra eliminación accidental
CRITICAL_PKGS=(
    "python3" "python3-pip" "python3-setuptools"
    "sudo" "wget" "curl"
    "screen" "less" "git" "openssh-server"
    "haproxy" "socat" "openssl" "ca-certificates"
    "fail2ban" "iptables" "iproute2" "net-tools"
    "lsof" "nano" "jq" "bc" "unzip" "zip"
    "systemd" "util-linux" "fdisk" "login" "passwd" "procps"
)
for hold_pkg in "${CRITICAL_PKGS[@]}"; do
    pkg_hold "$hold_pkg"
done

# Eliminar paquetes innecesarios (solo en Ubuntu/Debian)
if [[ "$PKG" == "apt" ]]; then
    REMOVE_PKGS=(
        "snapd" "lxd-agent" "lxd-installer" "cloud-guest-utils" "cloud-init"
        "cloud-utils" "open-vm-tools" "isc-dhcp-client" "ntfs-3g" "plymouth"
        "plymouth-theme-ubuntu-text" "fonts-ubuntu-console" "command-not-found"
        "command-not-found-data" "friendly-recovery" "installation-report"
        "landscape-common"
    )
    for pkg in "${REMOVE_PKGS[@]}"; do
        dpkg -l 2>/dev/null | grep -q "^ii.*${pkg}" && apt remove -y --no-autoremove "$pkg" >/dev/null 2>&1
    done
elif [[ "$PKG" == "dnf" ]]; then
    dnf remove -y snapd lxd-agent cloud-init cloud-utils open-vm-tools 2>/dev/null
elif [[ "$PKG" == "zypper" ]]; then
    zypper remove -y snapd lxd-agent cloud-init cloud-utils 2>/dev/null
fi

for hold_pkg in "${CRITICAL_PKGS[@]}"; do
    pkg_unhold "$hold_pkg"
done

run_cmd "Limpiando archivos temporales" "$LINENO" "rm -rf /tmp/* /var/tmp/* /root/.cache /root/.local; pkg_clean >/dev/null 2>&1"
run_cmd "Limpiando logs comprimidos" "$LINENO" "find /var/log -name '*.log.*' -delete 2>/dev/null; find /var/log -name '*.gz' -delete 2>/dev/null"
run_cmd "Vaciando journals viejos" "$LINENO" "journalctl --vacuum-time=1d"

DISABLE_SVCS=(
    "multipathd" "multipathd.socket" "ModemManager" "apport"
    "apport-autoreport.timer" "udisks2" "accounts-daemon" "avahi-daemon"
    "cups" "cups-browsed" "bluetooth" "wpa_supplicant"
    "snapd.service" "snapd.socket" "snapd.seeded.service"
)
for svc in "${DISABLE_SVCS[@]}"; do
    systemctl stop "$svc" 2>/dev/null; systemctl disable "$svc" 2>/dev/null
done

if [[ "$PKG" == "apt" ]]; then
    run_cmd "Eliminando snaps" "$LINENO" "snap remove --purge lxd 2>/dev/null; snap remove --purge lxd-agent 2>/dev/null; snap remove --purge core20 2>/dev/null; snap remove --purge core22 2>/dev/null; snap remove --purge snapd 2>/dev/null; rm -rf /snap /var/snap /var/lib/snapd"
fi
run_cmd "Limpiando historial" "$LINENO" "rm -f /root/.bash_history; history -c 2>/dev/null"

step "Optimizando red (BBR + FQ + buffers)..."

cat > /etc/sysctl.d/99-z-MoviVIP.conf << 'EOF'
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.core.rmem_default=262144
net.core.wmem_default=262144
net.ipv4.tcp_rmem=4096 262144 67108864
net.ipv4.tcp_wmem=4096 262144 67108864
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_low_latency=1
net.core.somaxconn=8192
net.core.netdev_max_backlog=16384
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=1024 65000
net.ipv4.tcp_timestamps=1
net.ipv4.udp_mem=32768 65536 262144
net.netfilter.nf_conntrack_max=524288
net.netfilter.nf_conntrack_udp_timeout=5
net.netfilter.nf_conntrack_udp_timeout_stream=15
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=2
fs.file-max=2097152
EOF
run_cmd "Aplicando parámetros de red" "$LINENO" "sysctl --system"
run_cmd "Aumentando límite de archivos abiertos" "$LINENO" "ulimit -n 1048576"

IFACE_NET=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
[[ -z "$IFACE_NET" ]] && IFACE_NET=$(ls /sys/class/net | grep -E '^(eth|ens|enp)' | head -n1)

run_cmd "Configurando MTU 1470 en ${IFACE_NET:-eth0}" "$LINENO" "ip link set dev '${IFACE_NET:-eth0}' mtu 1470"

# tc fq con parámetros avanzados solo funciona en kernel >= 6.13
KERN_VER=$(uname -r | cut -d. -f1,2)
KERN_MAJOR=$(echo "$KERN_VER" | cut -d. -f1)
KERN_MINOR=$(echo "$KERN_VER" | cut -d. -f2)
if [[ "$KERN_MAJOR" -gt 6 ]] || [[ "$KERN_MAJOR" -eq 6 && "$KERN_MINOR" -ge 13 ]]; then
    FQ_PARAMS="quantum 1492 initial_quantum 14920 flow_limit 1000 limit 10000 horizon 0 refill_delay 10 low_rate_threshold 10Mbit"
else
    FQ_PARAMS=""
fi
run_cmd "Configurando colas FQ gaming" "$LINENO" "tc qdisc del dev '${IFACE_NET:-eth0}' root 2>/dev/null; tc qdisc add dev '${IFACE_NET:-eth0}' root fq $FQ_PARAMS"

step "Configurando firewall de seguridad (puertos 22, 54321 y 8012 siempre abiertos)..."

run_cmd "Instalando iptables" "$LINENO" "pkg_install iptables"
run_cmd "Forzando rehash PATH" "$LINENO" "hash -r"

echo -e "      ${CYAN}→ Cerrando todos los puertos existentes...${RESET}"
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

echo -e "      ${CYAN}→ Abriendo puertos SSH/BD/emergencia (22,54321,8012)...${RESET}"
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 54321 -j ACCEPT
iptables -A INPUT -p tcp --dport 8012 -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

echo -e "      ${CYAN}→ Abriendo puertos HAProxy (80,443,8080,8443)...${RESET}"
for P in 80 443 8080 8443; do
    iptables -A INPUT -p tcp --dport "$P" -j ACCEPT
done

run_cmd "Creando cadena MOVIVIP_OUT" "$LINENO" "iptables -N MOVIVIP_OUT 2>/dev/null; iptables -C OUTPUT -j MOVIVIP_OUT 2>/dev/null || iptables -I OUTPUT 1 -j MOVIVIP_OUT"

iptables -t mangle -A PREROUTING -p udp --dport 7000:7999 -j DSCP --set-dscp-class af41 2>/dev/null
iptables -t mangle -A PREROUTING -p udp --dport 3478:3480 -j DSCP --set-dscp-class af41 2>/dev/null
iptables -t mangle -A PREROUTING -p udp --dport 8000:9000 -j DSCP --set-dscp-class af41 2>/dev/null

mkdir -p /etc/iptables

IFACE_BOOT="${IFACE_NET:-eth0}"

mkdir -p /etc/movivip/scripts
cat > /etc/movivip/scripts/boot-network.sh << 'BOOTEOF'
#!/bin/bash
sleep 5
sysctl --system >/dev/null 2>&1
iptables-restore < /etc/iptables/rules.v4 2>/dev/null
# GARANTIZAR puertos de emergencia SIEMPRE abiertos tras restore
for _p in 22 54321 8012; do
    iptables -C INPUT -p tcp --dport "$_p" -j ACCEPT 2>/dev/null || \
        iptables -I INPUT 1 -p tcp --dport "$_p" -j ACCEPT 2>/dev/null
done
# Si el INPUT policy es DROP y no hay reglas ACCEPT, abrir todo temporalmente
_RULES_COUNT=$(iptables -L INPUT -n 2>/dev/null | grep -c "ACCEPT")
if [[ "$_RULES_COUNT" -lt 3 ]]; then
    iptables -P INPUT ACCEPT 2>/dev/null
fi
iptables-save > /etc/iptables/rules.v4 2>/dev/null
# GARANTIZAR que SSH escuche en puertos 22 + 54321 + 8012
if [[ -f /etc/ssh/sshd_config.d/ports-movivip.conf ]]; then
    systemctl is-active ssh >/dev/null 2>&1 || systemctl restart ssh 2>/dev/null
fi
IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}')
[[ -z "$IFACE" ]] && IFACE=$(ls /sys/class/net | grep -E '^(eth|ens|enp)' | head -n1)
[[ -z "$IFACE" ]] && IFACE=eth0
ip link set dev "$IFACE" mtu 1470 2>/dev/null
tc qdisc del dev "$IFACE" root 2>/dev/null
tc qdisc add dev "$IFACE" root fq 2>/dev/null
modprobe tcp_bbr 2>/dev/null
BOOTEOF

cat > /etc/systemd/system/movivip-boot-network.service << 'SVCEOF'
[Unit]
Description=MoviVIP Network - Restaurar config de red al arranque
After=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/etc/movivip/scripts/boot-network.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVCEOF

run_cmd "Habilitando persistencia de red" "$LINENO" "chmod +x /etc/movivip/scripts/boot-network.sh; systemctl daemon-reload; systemctl enable movivip-boot-network.service"

#==============================
# [3] ⏰ LIMPIEZA AUTOMÁTICA (cron cada 30 min)
# ═══════════════════════════════════════════════════════════════
# [3] LIMPIEZA AUTOMÁTICA + AUTO-UPDATE
# ═══════════════════════════════════════════════════════════════

step "Configurando limpieza automática (cada 30 min)..."

run_cmd "Creando directorio de scripts" "$LINENO" "mkdir -p /etc/movivip/scripts"

cat > /etc/movivip/scripts/auto-cleanup.sh << 'CLEANEOF'
#!/bin/bash
# Multi-distro cleanup
if command -v apt-get >/dev/null 2>&1; then apt clean 2>/dev/null; apt autoremove -y 2>/dev/null
elif command -v dnf >/dev/null 2>&1; then dnf clean all 2>/dev/null; dnf autoremove -y 2>/dev/null
elif command -v zypper >/dev/null 2>&1; then zypper clean 2>/dev/null
elif command -v pacman >/dev/null 2>&1; then pacman -Scc --noconfirm 2>/dev/null
fi
find /var/log -name '*.log.*' -mmin +1440 -delete 2>/dev/null
find /var/log -name '*.gz' -delete 2>/dev/null
find /tmp -type f -mmin +1440 -delete 2>/dev/null
find /var/tmp -type f -mmin +1440 -delete 2>/dev/null
journalctl --vacuum-time=1d 2>/dev/null
rm -rf /root/.cache/pip 2>/dev/null /root/.cache/apt 2>/dev/null
SWAP_USED=$(free | awk '/Swap/{print $3}')
if [[ "$SWAP_USED" -eq 0 ]]; then swapoff -a 2>/dev/null; swapon -a 2>/dev/null; fi
df -h / | awk 'NR==2 {print "[Auto-Cleanup] "$4" libre ("$5" usado)"}' >> /var/log/movivip-cleanup.log 2>/dev/null
CLEANEOF

run_cmd "Configurando cron auto-cleanup" "$LINENO" "chmod +x /etc/movivip/scripts/auto-cleanup.sh; (crontab -l 2>/dev/null | grep -v 'auto-cleanup'; echo '*/30 * * * * bash /etc/movivip/scripts/auto-cleanup.sh >/dev/null 2>&1') | crontab -"

step "Configurando auto-update (cada 2 días)..."
run_cmd "Configurando cron auto-update" "$LINENO" "chmod +x /etc/movivip/auto-update.sh 2>/dev/null; (crontab -l 2>/dev/null | grep -v 'auto-update'; echo '0 3 */2 * * bash /etc/movivip/auto-update.sh >/dev/null 2>&1') | crontab -"
run_cmd "Configurando cron expira-exacta (minuto)" "$LINENO" "chmod +x /etc/movivip/scripts/expira-exacta.sh 2>/dev/null; (crontab -l 2>/dev/null | grep -v 'expira-exacta'; echo '* * * * * bash /etc/movivip/scripts/expira-exacta.sh >/dev/null 2>&1') | crontab -"

# ═══════════════════════════════════════════════════════════════
# [4] GUARDAR VALORES DE RED
# ═══════════════════════════════════════════════════════════════

step "Guardando valores de red..."

MTU_CURRENT=$(ip link show "${IFACE_NET:-eth0}" 2>/dev/null | grep -o "mtu [0-9]*" | awk '{print $2}')
MTU_CURRENT="${MTU_CURRENT:-1470}"

cat >> /etc/movivip/config.conf << CONFEOF

NET_MTU="$MTU_CURRENT"
NET_RMEM="67108864"
NET_WMEM="67108864"
NET_SOMAXCONN="8192"
NET_BACKLOG="16384"
NET_SWAPPINESS="10"
NET_CLEANUP_INTERVAL="30"
CONFEOF

step "Verificando recursos..."

RAM_TOTAL=$(free -m | awk '/Mem:/{print $2}')
RAM_USED=$(free -m | awk '/Mem:/{print $3}')
RAM_FREE=$(free -m | awk '/Mem:/{print $7}')
RAM_PERCENT=$(( RAM_USED * 100 / RAM_TOTAL ))
CPU_CORES=$(nproc)
CPU_LOAD=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | tr -d ' ')
DISK_USED=$(df -h / | awk 'NR==2 {print $5}')
DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
TOP_RAM=$(ps aux --sort=-%mem | head -5 | awk 'NR>1{printf "     %s %s%% %s\n", $1, $4, $11}')

echo ""
echo -e "${CYAN}   ╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}   ║${GOLD}           📊 RECURSOS DEL VPS 📊${RESET}${CYAN}                ║${RESET}"
echo -e "${CYAN}   ╠══════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}   ║${WHITE}  💾 RAM: ${RAM_USED}MB / ${RAM_TOTAL}MB (${RAM_PERCENT}%)${RESET}${CYAN}              ║${RESET}"
echo -e "${CYAN}   ║${WHITE}  ⚡ CPU: ${CPU_CORES} cores | Load: ${CPU_LOAD}${RESET}${CYAN}            ║${RESET}"
echo -e "${CYAN}   ║${WHITE}  💿 Disco: ${DISK_USED} usado | ${DISK_FREE} libre${RESET}${CYAN}         ║${RESET}"
echo -e "${CYAN}   ╠══════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}   ║${GOLD}  🏆 Top procesos por RAM:${RESET}${CYAN}                      ║${RESET}"
echo -e "${CYAN}   ║${WHITE}${TOP_RAM}${RESET}${CYAN}  ║${RESET}"
echo -e "${CYAN}   ╚══════════════════════════════════════════════════╝${RESET}"
echo ""

# ═══════════════════════════════════════════════════════════════
# INSTALAR OPENSSH
# ═══════════════════════════════════════════════════════════════

step "Instalando OpenSSH..."

run_cmd "Instalando openssh-server" "$LINENO" "pkg_install openssh-server"
run_cmd "Habilitando servicio SSH" "$LINENO" "systemctl enable ssh"

# Configurar SSH en puertos 22 + 54321 + 8012 (siempre accesibles)
echo -e "      ${CYAN}→ Configurando SSH multi-puerto (22, 54321, 8012)...${RESET}"
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/ports-movivip.conf << 'SSHEOF'
# MoviVIP Network - Puertos SSH de emergencia
# Siempre abiertos: 22 (principal), 54321 (backup), 8012 (emergencia)
Port 22
Port 54321
Port 8012
SSHEOF
# Quitar cualquier línea Port duplicada del config principal
sed -i '/^Port /d' /etc/ssh/sshd_config 2>/dev/null
run_cmd "Reiniciando servicio SSH" "$LINENO" "systemctl restart ssh"

# ==============================  
  
# CONFIG SERVER  
  
# ==============================  

step "Configurando servidor..."

run_cmd "Asegurando curl" "$LINENO" "pkg_install curl"

clear  

echo "$(mv_hr)"  
echo "$(trx '        CONFIGURACIÓN DEL SERVIDOR')"  
echo "$(mv_hr)"  
  
# ── Cloudflare v7.3.9: consultar dominios de tu cuenta + crear subdominio (A) ──
# SlowDNS reutilizará ese subdominio y creará A + NS automáticamente (cf_ensure_ns).
cf_listar_zonas() {
    local ZR
    CF_ZONES_NAME=(); CF_ZONES_ID=(); CF_ZONES_COUNT=0
    ZR=$(curl -s --max-time 15 "https://api.cloudflare.com/client/v4/zones?per_page=50" -H "X-Auth-Email: $CF_EMAIL" -H "X-Auth-Key: $CF_KEY")
    eval "$(echo "$ZR" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    rs=[r for r in d.get('result',[]) if r.get('status')=='active']
except: rs=[]
for r in rs:
    print('CF_ZONES_NAME+=(\"' + r['name'] + '\")')
    print('CF_ZONES_ID+=(\"' + r['id'] + '\")')
print('CF_ZONES_COUNT=' + str(len(rs)))" 2>/dev/null)"
    [[ "${CF_ZONES_COUNT:-0}" -gt 0 ]]
}

cf_rand_sub() {
    local n
    n="$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -dc 'a-z0-9' | head -c 6)"
    [[ -z "$n" ]] && n="$(date +%s | tail -c 6)"
    [[ -z "$n" ]] && n="$RANDOM"
    printf 'srv-%s' "$n"
}

cf_crear_subdominio() {
    local CR_ZID CR_VPSIP CR_A_AC I ZC
    CF_SUB_FQDN="${CF_SUB_FQDN// /}"
    if [[ -z "$CF_SUB_FQDN" ]]; then
        CF_SUB_NAME="${CF_SUB_NAME// /}"
        if [[ -z "$CF_SUB_NAME" ]]; then
            CF_SUB_NAME="$(cf_rand_sub)"
            [[ -z "$CF_SUB_NAME" ]] && CF_SUB_NAME="srv-$RANDOM$(date +%s | tail -c 4)"
        fi
        [[ -z "$CF_ZONE" && "${CF_ZONES_COUNT:-0}" -gt 0 ]] && CF_ZONE="${CF_ZONES_NAME[0]}"
        CF_SUB_FQDN="$CF_SUB_NAME.$CF_ZONE"
    fi
    CR_ZID=""; ZC=""
    for I in "${!CF_ZONES_NAME[@]}"; do
        if [[ "$CF_SUB_FQDN" == "${CF_ZONES_NAME[$I]}" || "$CF_SUB_FQDN" == *".${CF_ZONES_NAME[$I]}" ]]; then
            if [[ -z "$CR_ZID" || "${#CF_ZONES_NAME[$I]}" -gt "${#ZC}" ]]; then
                CR_ZID="${CF_ZONES_ID[$I]}"; ZC="${CF_ZONES_NAME[$I]}"
            fi
        fi
    done
    if [[ -z "$CR_ZID" ]]; then
        echo -e "      ${RED}✖${RESET} No se encontró el dominio $CF_SUB_FQDN en tu cuenta Cloudflare."
        echo -e "      ${GRAY}  Usa uno de los dominios listados (o colócalo manualmente abajo).${RESET}"
        return 1
    fi
    CR_VPSIP=$(curl -s --max-time 10 ifconfig.me || hostname -I | awk '{print $1}')
    CR_A_AC=$(curl -s --max-time 15 -X POST "https://api.cloudflare.com/client/v4/zones/$CR_ZID/dns_records" -H "X-Auth-Email: $CF_EMAIL" -H "X-Auth-Key: $CF_KEY" -H "Content-Type: application/json" --data "{\"type\":\"A\",\"name\":\"$CF_SUB_FQDN\",\"content\":\"$CR_VPSIP\",\"ttl\":1,\"proxied\":false}" | python3 -c "import sys,json; print('ok' if json.load(sys.stdin).get('success') else 'err')" 2>/dev/null)
    if [[ "$CR_A_AC" == "ok" ]]; then
        echo -e "      ${GREEN}✔${RESET} Subdominio creado: ${WHITE}${CF_SUB_FQDN}${RESET} → $CR_VPSIP"
        sed -i '/^CF_SUB_FQDN=/d' /etc/movivip/cf.conf 2>/dev/null || true
        echo "CF_SUB_FQDN=\"$CF_SUB_FQDN\"" >> /etc/movivip/cf.conf
        export CF_SUB_FQDN
        return 0
    fi
    echo -e "      ${RED}✖${RESET} Error creando $CF_SUB_FQDN (¿API Key con permiso DNS edit?)."
    echo -e "      ${GRAY}  Podrás colocarlo manualmente en el campo Dominio Cloudflare.${RESET}"
    return 1
}

if [[ -t 0 && "$AUTO_INSTALL" == "0" ]]; then
    # ── Cloudflare OPCIONAL (v7.3.9): consulta los dominios de tu cuenta CF ──
    # Responder S: consulta Cloudflare, muestra tus dominios, crea el subdominio
    # (nombre que escribas o aleatorio) y el SlowDNS lo reutiliza (A + NS automáticos).
    CF_MAIN_ASK=""
    read -rp "$(trx '🔑 ¿Configurar Cloudflare (DNS automático + SlowDNS)? (s/N): ')" CF_MAIN_ASK
    if [[ "$CF_MAIN_ASK" =~ ^[Ss]$ ]]; then
        [[ -z "${CF_EMAIL:-}" ]] && read -rp "$(trx '   Email Cloudflare: ')" CF_EMAIL
        [[ -z "${CF_KEY:-}" ]]  && read -rp "$(trx '   Global API Key: ')" CF_KEY
        if [[ -n "$CF_EMAIL" && -n "$CF_KEY" ]]; then
            mkdir -p /etc/movivip
            cat > /etc/movivip/cf.conf <<CFEOF
CF_EMAIL="$CF_EMAIL"
CF_KEY="$CF_KEY"
CFEOF
            chmod 600 /etc/movivip/cf.conf
            export CF_EMAIL CF_KEY
            echo ""
            echo -e "      ${GREEN}✔${RESET} Credenciales guardadas, consultando dominios..."
            if cf_listar_zonas; then
                echo -e "      ${CYAN}🔎 Dominios en tu cuenta Cloudflare:${RESET}"
                for I in "${!CF_ZONES_NAME[@]}"; do
                    echo -e "        $((I+1))) ${WHITE}${CF_ZONES_NAME[$I]}${RESET}"
                done
                if [[ "${CF_ZONES_COUNT}" -eq 1 ]]; then
                    CF_ZONE="${CF_ZONES_NAME[0]}"
                    echo -e "      ${GRAY}→ Se usará tu dominio ${WHITE}${CF_ZONE}${RESET}"
                    read -rp "$(trx '   🌐 Nombre del subdominio (Ej: gratis, Enter = aleatorio): ')" CF_SUB_NAME
                    CF_SUB_NAME="${CF_SUB_NAME// /}"
                    if [[ "$CF_SUB_NAME" == *.* ]]; then
                        CF_SUB_FQDN="$CF_SUB_NAME"
                    elif [[ -n "$CF_SUB_NAME" ]]; then
                        CF_SUB_FQDN="$CF_SUB_NAME.$CF_ZONE"
                    else
                        CF_SUB_NAME="$(cf_rand_sub)"
                        CF_SUB_FQDN="$CF_SUB_NAME.$CF_ZONE"
                    fi
                else
                    read -rp "$(trx '   🌐 Escribe tu subdominio completo (Ej: gratis.midominio.com) o Nº: ')" CF_SUB_RAW
                    CF_SUB_RAW="${CF_SUB_RAW// /}"
                    if [[ "$CF_SUB_RAW" =~ ^[1-9][0-9]*$ ]]; then
                        CF_ZONE="${CF_ZONES_NAME[$((CF_SUB_RAW-1))]}"
                        read -rp "$(trx '   🌐 Nombre del subdominio (Ej: gratis, Enter = aleatorio): ')" CF_SUB_NAME
                        CF_SUB_NAME="${CF_SUB_NAME// /}"
                        [[ -z "$CF_SUB_NAME" ]] && CF_SUB_NAME="$(cf_rand_sub)"
                        CF_SUB_FQDN="$CF_SUB_NAME.$CF_ZONE"
                    else
                        CF_SUB_FQDN="$CF_SUB_RAW"
                    fi
                fi
                cf_crear_subdominio || true
            else
                echo -e "      ${RED}✖${RESET} No se pudieron consultar tus dominios (revisa Email/API Key)."
                echo -e "      ${GRAY}  Continúa: coloca tu dominio manualmente abajo.${RESET}"
            fi
        else
            echo ""
            echo -e "      ${GRAY}ℹ️  Cloudflare omitido — podrás configurar SlowDNS manualmente.${RESET}"
            unset CF_EMAIL CF_KEY 2>/dev/null || true
        fi
    else
        echo ""
        echo -e "      ${GRAY}ℹ️  Cloudflare omitido — dominios manuales + SlowDNS manual.${RESET}"
    fi
    if [[ -n "${CF_SUB_FQDN:-}" ]]; then
        read -rp "$(trx '🌐 Dominio Cloudflare (Enter = ')$CF_SUB_FQDN): " SERVER_DOMAIN
        SERVER_DOMAIN="${SERVER_DOMAIN:-$CF_SUB_FQDN}"
    else
        read -p "$(trx '🌐 Dominio Cloudflare: ')" SERVER_DOMAIN
    fi
    read -p "$(trx '🌐 Dominio Cloudfront (Enter si no): ')" CLOUDFRONT_DOMAIN
    read -p "$(trx '🌐 Dominio No-IP / DDNS (Enter si no): ')" NOIP_DOMAIN
    echo ""
    echo -e "${CYAN}━━━ Información del Banner SSH ━━━${RESET}"
    echo -e "${GRAY}  (Presiona Enter para usar valores por defecto)${RESET}"
    echo ""
    read -p "$(trx '🔤 Nombre de tu marca (Enter='VPN'): ')" BRAND_NAME
    read -p "$(trx '🛡️  Emoji de escudo (Enter='🛡️'): ')" BRAND_EMOJI
    read -p "$(trx '💬 Lema/título (Enter='PREMIUM VPN'): ')" BRAND_SLOGAN
    read -p "$(trx '🌐 Tu sitio web (Enter=vacío): ')" BRAND_WEB
    read -p "$(trx '👤 Soporte (URL o @usuario, Enter=vacío): ')" SUPPORT_LINK
    read -p "$(trx '📢 Canal Telegram (URL o @usuario, Enter=vacío): ')" TG_CHANNEL
    read -p "$(trx '👥 Grupo Telegram (URL o @usuario, Enter=vacío): ')" TG_GROUP
else
    # ── AUTO_INSTALL: Cloudflare del CLIENTE (v8.2.1) ──
    # CADA CLIENTE usa SUS PROPIAS credenciales vía env:
    #   CF_EMAIL, CF_KEY, CF_ZONE (opcional), CF_SUB_NAME (opcional), CF_SUB_FQDN (opcional)
    # Si el cliente pasó sus credenciales → se listan SUS zonas y se crea el
    # subdominio A en SU cuenta automáticamente (SlowDNS lo reutiliza).
    # Sin credenciales del cliente → se omite (igual que antes).
    CF_EMAIL="${CF_EMAIL:-}"
    CF_KEY="${CF_KEY:-}"
    CF_ZONE="${CF_ZONE:-}"
    CF_SUB_NAME="${CF_SUB_NAME:-}"
    CF_SUB_FQDN="${CF_SUB_FQDN:-}"
    if [[ -n "${CF_EMAIL:-}" && -n "${CF_KEY:-}" ]]; then
        export CF_EMAIL CF_KEY
        if cf_listar_zonas; then
            # Elegir la primera zona activa del cliente si no se especificó
            [[ -z "$CF_ZONE" && "${CF_ZONES_COUNT:-0}" -gt 0 ]] && CF_ZONE="${CF_ZONES_NAME[0]}"
            if [[ -z "$CF_SUB_FQDN" ]]; then
                [[ -z "$CF_SUB_NAME" ]] && CF_SUB_NAME="$(cf_rand_sub)"
                [[ -z "$CF_SUB_NAME" ]] && CF_SUB_NAME="srv-$RANDOM$(date +%s | tail -c 4)"
                CF_SUB_FQDN="$CF_SUB_NAME.$CF_ZONE"
            fi
            cf_crear_subdominio || true
        else
            echo -e "      ${YELLOW}⚠${RESET} No se pudieron consultar dominios Cloudflare (revisa credenciales)."
        fi
    fi
    SERVER_DOMAIN="${SERVER_DOMAIN:-$CF_SUB_FQDN}"
    CLOUDFRONT_DOMAIN="${CLOUDFRONT_DOMAIN:-}"
    NOIP_DOMAIN="${NOIP_DOMAIN:-}"
    BRAND_NAME="${BRAND_NAME:-}"
    BRAND_EMOJI="${BRAND_EMOJI:-}"
    BRAND_SLOGAN="${BRAND_SLOGAN:-}"
    BRAND_WEB="${BRAND_WEB:-}"
    SUPPORT_LINK="${SUPPORT_LINK:-}"
    TG_CHANNEL="${TG_CHANNEL:-}"
    TG_GROUP="${TG_GROUP:-}"
fi  

if [[ -n "$SERVER_DOMAIN" ]] && ! [[ "$SERVER_DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "      ${RED}✖ '$SERVER_DOMAIN' no parece un dominio válido${RESET}"
    echo -e "      ${GRAY}  → Ignorando dominio inválido${RESET}"
    SERVER_DOMAIN=""
fi
  
SERVER_IP=$(curl -s ifconfig.me)  
  
CLOUDFLARE_STATUS="OFF"  
SSL_TUNNEL="OFF"  
DOMAIN_IP_MATCH="NO"  
PROXY_STATUS="UNKNOWN"  
if [[ -n "$SERVER_DOMAIN" ]]; then  

echo ""        
echo "$(trx '🔍 Verificando dominio...')"        
    
DOMAIN_IP=$(dig +short "$SERVER_DOMAIN" | head -n1)        
    
if [[ "$DOMAIN_IP" == "$SERVER_IP" ]]; then
    DOMAIN_IP_MATCH="YES"
    echo "$(trx '✅ Dominio apunta al VPS')"
    echo "$(trx 'ℹ️ El certificado SSL se podrá instalar desde el menú.')"

    SSL_TUNNEL="OFF"

else
    echo "$(trx '❌ Dominio no apunta al VPS')"
    SSL_TUNNEL="OFF"
fi
    
# Cloudflare detect        
CF=$(dig +short NS "$SERVER_DOMAIN" | grep cloudflare)        
    
[[ -n "$CF" ]] && CLOUDFLARE_STATUS="ON"  
  
fi  
BASE="/etc/movivip"  
# ==================================================
# Credenciales Cloudflare (v7.3.7): ya se preguntaron arriba (opcional).
# Aquí solo se persisten si vienen por env (headless) y aún no hay cf.conf.
# SlowDNS las usará para crear registros A+NS automáticamente.
# ==================================================
if [[ ! -f "$BASE/cf.conf" ]] && [[ -n "${CF_EMAIL:-}" && -n "${CF_KEY:-}" ]]; then
    mkdir -p "$BASE"
    cat > "$BASE/cf.conf" <<CFEOF
CF_EMAIL="$CF_EMAIL"
CF_KEY="$CF_KEY"
CFEOF
    chmod 600 "$BASE/cf.conf"
    export CF_EMAIL CF_KEY
    echo "$(trx '   ✅ Credenciales Cloudflare guardadas (las usará SlowDNS).')"
fi


mkdir -p $BASE/{protocolos,usuarios,sistema,logs}  

#==============================  

# CONFIG FINAL  

#==============================  

# Secreto maestro para derivar contraseñas de cuentas HWID.
# La contraseña de un usuario HWID = f(HWID + este secreto), nadie la elige.
# Si cambias este valor, TODAS las cuentas HWID dejan de funcionar.
HWID_SECRET=$(openssl rand -hex 24 2>/dev/null || (echo "mv$(date +%s%N)$RANDOM" | sha256sum | cut -c1-48))

# v7.3.11: saneo de dominios — nunca emails/API keys en config.conf
if [[ -n "${CLOUDFRONT_DOMAIN:-}" ]] && ! [[ "$CLOUDFRONT_DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "      ${RED}✖${RESET} CLOUDFRONT_DOMAIN ($CLOUDFRONT_DOMAIN) no es un dominio valido — se limpia"
    CLOUDFRONT_DOMAIN=""
fi
if [[ -n "${NOIP_DOMAIN:-}" ]] && ! [[ "$NOIP_DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo -e "      ${RED}✖${RESET} NOIP_DOMAIN ($NOIP_DOMAIN) no es un dominio valido — se limpia"
    NOIP_DOMAIN=""
fi
# v7.3.11: modo automatico Cloudflare — el subdominio creado pasa a SERVER_DOMAIN
if [[ -z "${SERVER_DOMAIN:-}" && -n "${CF_SUB_FQDN:-}" ]]; then
    SERVER_DOMAIN="$CF_SUB_FQDN"
    echo -e "      ${GREEN}✔${RESET} Usando subdominio automatico Cloudflare como dominio: ${WHITE}$SERVER_DOMAIN${RESET}"
fi

cat > "$BASE/config.conf" <<EOF
SERVER_DOMAIN="$SERVER_DOMAIN"
CLOUDFRONT_DOMAIN="$CLOUDFRONT_DOMAIN"
NOIP_DOMAIN="$NOIP_DOMAIN"

# ==============================
# BANNER INFO (SSH login banner)
# ==============================
BRAND_NAME="${BRAND_NAME:-}"
BRAND_EMOJI="${BRAND_EMOJI:-}"
BRAND_SLOGAN="${BRAND_SLOGAN:-}"
BRAND_WEB="${BRAND_WEB:-}"
SUPPORT_LINK="${SUPPORT_LINK:-}"
TG_CHANNEL="${TG_CHANNEL:-}"
TG_GROUP="${TG_GROUP:-}"

#==============================
# SECRETO MAESTRO HWID
# Contraseña de cuenta HWID = derivada(HWID + HWID_SECRET).
# No compartirlo. Cambiarlo invalida todas las cuentas HWID.
#==============================

HWID_SECRET="$HWID_SECRET"

CLOUDFLARE_STATUS="$CLOUDFLARE_STATUS"
SSL_TUNNEL="ON"
DOMAIN_IP_MATCH="$DOMAIN_IP_MATCH"
PROXY_STATUS="$PROXY_STATUS"

#==============================
# TRAFICO BASE DEL VPS (bytes)
# Opcional: pon aqui el conteo acumulado que muestra tu proveedor
# para que el panel de consumo muestre el total real del VPS.
# Ej: 6.02 TB = 6020000000000 | 6.6 TB = 6600000000000
#==============================

VPS_TRAFFIC_BASE_RX=0
VPS_TRAFFIC_BASE_TX=0

AUTO_START=OFF

#==============================
# AUTO-UPDATE (checker por cron)
# ON  → el cron comprueba e instala updates silenciosamente
# OFF → el cron solo repara integridad (BOM/sintaxis), nunca actualiza
# Toggle: menú principal → 🛠 [14] Auto-update
#==============================

AUTO_UPDATE=ON

#==============================
# IDIOMA
#==============================

LANGUAGE="$INSTALL_LANG"

#==============================
# WELCOME 3D (plan · versión · zona horaria)
#==============================

INSTALL_PLAN="${WELCOME_PLAN:-premium}"
INSTALL_PLAN_COSTO="${WELCOME_PLAN_COSTO:-20}"
INSTALL_VERSION="${WELCOME_VERSION:-stable}"
SYS_TZ="${WELCOME_TZ:-}"

#==============================
# PROTOCOLOS
#==============================

OPENSSH=ON
SYSTEMDNS=OFF
WEBSOCKET=OFF
ZIPVPN=OFF
DROPBEAR=OFF
SSL=ON

BADVPN=OFF
UDP_CUSTOM=OFF

SLOWDNS=OFF
V2RAY=OFF
HYSTERIA=OFF

OPENVPN=OFF
SQUID=OFF
TROJAN=OFF
V2RAY=OFF
SHADOWSOCKS=OFF
XHTTP=OFF
BHTTP=OFF
BTUN=OFF
PAYLOAD=OFF
SOCKS5=OFF
HCR=OFF
WEBMIN=OFF
FAIL2BAN=ON
BBR=OFF

#==============================
# LÍMITES DE CONSUMO DE RED (bytes)
# 0 = sin límite. Configura desde el menú Herramientas → [10]
#==============================

NET_LIMIT_IN=0
NET_LIMIT_OUT=0
EOF
#==============================  
  
# INSTALACIÓN FINAL  
  
#==============================  
  
step "Finalizando instalación..."

run_cmd "Estableciendo permisos del directorio" "$LINENO" "chmod -R 777 /etc/movivip"
run_cmd "Creando comandos de menú (launchers seguros)" "$LINENO" "mkdir -p /usr/local/bin && for L in menu protocolos herramientas usuarios; do cp -f \"/etc/movivip/launchers/\$L\" \"/usr/local/bin/\$L\" 2>/dev/null && chmod +x \"/usr/local/bin/\$L\"; done; if [ ! -x /usr/local/bin/menu ] && [ -f /etc/movivip/lib/launch.sh ]; then printf '#!/bin/bash\nexec bash /etc/movivip/lib/launch.sh /etc/movivip/menu.sh \"\$@\"\n' > /usr/local/bin/menu; chmod +x /usr/local/bin/menu; fi"  
  
#==============================  
  
# RESUMEN FINAL  
  
#==============================  
  
step "Instalando MoviVIP Network desde archivos locales..."

# Detectar directorio origen (donde está el ZIP extraído o el repo local)
# Prioridad: 1) MOVIVIP_SRC (env del stub con payload pre-extraído),
#            2) directorio actual si tiene menu.sh, 3) /root/scrip_vps_todo, 4) /tmp/multi-script (fallback git)
SRC_DIR=""
if [[ -n "${MOVIVIP_SRC:-}" && -f "$MOVIVIP_SRC/menu.sh" && -d "$MOVIVIP_SRC/protocolos" ]]; then
    SRC_DIR="$MOVIVIP_SRC"
elif [[ -f "$(pwd)/menu.sh" && -d "$(pwd)/protocolos" ]]; then
    SRC_DIR="$(pwd)"
elif [[ -f /root/scrip_vps_todo/menu.sh && -d /root/scrip_vps_todo/protocolos ]]; then
    SRC_DIR="/root/scrip_vps_todo"
elif [[ -f /tmp/multi-script/menu.sh && -d /tmp/multi-script/protocolos ]]; then
    SRC_DIR="/tmp/multi-script"
else
    # Fallback: descargar el PAQUETE COMPLETO desde GitHub Releases.
    # NO usar el tarball del repo: la rama main es solo un stub
    # (README.md + update.sh + version.txt) y la rama master ya no existe.
    _mvbdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
    _mvbver="$(tr -d ' \r\n' < "$_mvbdir/version.txt" 2>/dev/null)"
    [[ -n "$_mvbver" ]] || _mvbver="8.2.16"
    _mvburl="https://github.com/studioanime977/MoviVIPNetwork/releases/download/v${_mvbver}/MoviVIPNetwork_v${_mvbver}.tar.gz"
    run_cmd "Instalando git" "$LINENO" "pkg_install git"
    run_cmd "Descargando paquete oficial (release v${_mvbver})" "$LINENO" "rm -rf /tmp/multi-script /tmp/movivip-src.tar.gz; mkdir -p /tmp/multi-script; for i in 1 2 3; do curl -fsSL --max-time 300 '$_mvburl' -o /tmp/movivip-src.tar.gz && break; sleep 5; done; tar -xzf /tmp/movivip-src.tar.gz -C /tmp/multi-script --strip-components=1"
    SRC_DIR="/tmp/multi-script"
fi

# --- v8.2.13: validacion fail-closed del payload ANTES de copiar ---
# Nunca desplegar un paquete incompleto. Si faltan archivos criticos se aborta
# ANTES de tocar /etc/movivip ni /usr/local/bin/menu, evitando el error
# "/etc/movivip/lib/launch.sh: No such file or directory".
# (v8.2.12 validaba DESPUES de la copia y la rama /tmp/multi-script ya habia
#  borrado el directorio fuente con rm -rf -> aborto espurio en instalacion
#  limpia. Ahora se valida antes y con detalle de que falta.)
if [[ -z "$SRC_DIR" ]]; then
    echo ""
    echo "[ABORTADO] No se pudo localizar el paquete MoviVIP Network."
    echo "[ABORTADO] La descarga desde GitHub Releases no quedo en ningun directorio valido."
    echo ""
    exit 1
fi
_mv_missing=""
[[ -f "$SRC_DIR/menu.sh" ]] || _mv_missing="$_mv_missing menu.sh"
[[ -d "$SRC_DIR/protocolos" ]] || _mv_missing="$_mv_missing protocolos/"
[[ -f "$SRC_DIR/lib/launch.sh" ]] || _mv_missing="$_mv_missing lib/launch.sh"
[[ -d "$SRC_DIR/herramientas" ]] || _mv_missing="$_mv_missing herramientas/"
if [[ -n "$_mv_missing" ]]; then
    echo ""
    echo "[ABORTADO] Paquete incompleto detectado en: $SRC_DIR"
    echo "[ABORTADO] Faltan archivos criticos:$_mv_missing"
    echo "[ABORTADO] No se creo ningun launcher. Reintenta o usa el tarball completo."
    echo ""
    exit 1
fi

if [[ -n "$SRC_DIR" && "$SRC_DIR" != "/tmp/multi-script" ]]; then
    run_cmd "Copiando archivos desde $SRC_DIR" "$LINENO" "mkdir -p /etc/movivip; cp -a \"$SRC_DIR\"/. /etc/movivip/; chmod -R +x /etc/movivip"
else
    run_cmd "Copiando archivos al sistema" "$LINENO" "mkdir -p /etc/movivip; cp -a /tmp/multi-script/. /etc/movivip/; chmod -R +x /etc/movivip; rm -rf /tmp/multi-script"
fi

# --- v8.2.12: (re)crear launchers ahora que el payload esta en /etc/movivip ---
# Antes se creaban ANTES de copiar los archivos; en una instalacion limpia caia
# al stub que apunta a /etc/movivip/lib/launch.sh inexistente y nunca se
# sustituia por el launcher real (ya era ejecutable).
if [[ -f /etc/movivip/launchers/menu && -f /etc/movivip/lib/launch.sh ]]; then
    mkdir -p /usr/local/bin
    for _L in menu protocolos herramientas usuarios; do
        if [[ -f "/etc/movivip/launchers/$_L" ]]; then
            cp -f "/etc/movivip/launchers/$_L" "/usr/local/bin/$_L" 2>/dev/null && chmod +x "/usr/local/bin/$_L"
        fi
    done
    if [[ ! -x /usr/local/bin/menu ]]; then
        printf '#!/bin/bash\nexec bash /etc/movivip/lib/launch.sh /etc/movivip/menu.sh "$@"\n' > /usr/local/bin/menu
        chmod +x /usr/local/bin/menu
    fi
fi

# --- v8.2.12: NOTIFICACIÓN DE ACTIVACIÓN al final del flujo ---
# Ahora el payload ya está en /etc/movivip (incluye notify-activation.sh).
# En instalación FRESCA intentamos restaurar .env-bot desde el backup
# cifrado de Firebase (herramientas/env-bot-sync.sh restore; requiere
# .env-seed + master key del servidor — si no hay backup/seed, el helper
# falla y notify-activation.sh sale silencioso, que es el comportamiento
# correcto: sin token no hay notificación y NO se rompe la instalación).
if [[ "$LICENSE_VALID" == "yes" && -n "${INCOMING_KEY:-}" ]]; then
    if [[ -f /etc/movivip/.env-bot ]] || { [[ -x /etc/movivip/herramientas/env-bot-sync.sh ]] && /etc/movivip/herramientas/env-bot-sync.sh restore >/dev/null 2>&1; }; then
        if [[ -x /etc/movivip/herramientas/notify-activation.sh ]]; then
            /etc/movivip/herramientas/notify-activation.sh "${INCOMING_KEY}" >/dev/null 2>&1 &
        fi
    fi
fi

# FIX v7.0.1b: la limpieza para reinstalación ejecuta "rm -rf /etc/movivip"
# (L1138) DESPUÉS de persistir licencia.conf (L873) y antes del cp -a, así
# que el archivo se pierde y verify_install queda 2/3. Re-persistirlo aquí,
# al final del flujo, con los datos reales leídos de Firebase en la validación.
if [[ "$LICENSE_VALID" == "yes" && -n "${INCOMING_KEY:-}" ]]; then
    FB_REAL_PLAN="${FB_REAL_PLAN:-standard}"; FB_REAL_CLIENTE="${FB_REAL_CLIENTE:-desconocido}"
    FB_REAL_TIPO="${FB_REAL_TIPO:-cliente}"; FB_REAL_EXPIRA="${FB_REAL_EXPIRA:-0}"
    cat > /etc/movivip/licencia.conf << LICEOF
# Movivip Network — Licencia (sincronizada con Firebase EN VIVO)
# ⚠ NO edites este archivo: se sobreescribe en cada validación.
KEY="$INCOMING_KEY"
PLAN="$FB_REAL_PLAN"
CLIENTE="$FB_REAL_CLIENTE"
TIPO="$FB_REAL_TIPO"
EXPIRA="$FB_REAL_EXPIRA"
FECHA_ACTIVACION="$(date +%Y-%m-%d)"
LICEOF
    echo -e "${GREEN}✔ Licencia persistida en /etc/movivip/licencia.conf${RESET}"
fi

# FIX v8.2.15: RE-CREAR /etc/movivip/activaciones AL FINAL del flujo.
# La limpieza de reinstalación ejecuta "rm -rf /etc/movivip" (limpia [4/4])
# DESPUÉS de que la rama rápida crea las activaciones → el dir local se perdía
# (aunque el PATCH a Firebase ya se hubiera hecho). Aquí, tras el cp -a final,
# el directorio ya está poblado y la activación persiste exactamente igual que
# licencia.conf (FIX v7.0.1b). Corrige la rama rápida Y la de validación en vivo.
if [[ "$LICENSE_VALID" == "yes" && -n "${INCOMING_KEY:-}" ]]; then
    mkdir -p /etc/movivip/activaciones
    DEVICE_ID=$(cat /etc/machine-id 2>/dev/null | head -c 16)
    # Evitar DEVICE_ID vacío (cat|head siempre devuelve 0 → || echo no dispara)
    [[ -z "$DEVICE_ID" ]] && DEVICE_ID="unknown"
    if [[ "$DEVICE_ID" == "unknown" ]]; then
        VPS_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "unknown")
        DEVICE_ID=$(echo -n "${VPS_IP}$(date +%s)" | sha256sum | head -c 16)
    fi
    VPS_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || echo "unknown")
    echo "${VPS_IP}" > "/etc/movivip/activaciones/${DEVICE_ID}.ip"
    echo "$(date +%s)" > "/etc/movivip/activaciones/${DEVICE_ID}.timestamp"
    echo "${INCOMING_KEY}" > "/etc/movivip/activaciones/${DEVICE_ID}.key"
    registrar_activacion "${INCOMING_KEY}"
    echo -e "${GREEN}✔ Activaciones registradas: ${DEVICE_ID}.ip/.timestamp/.key + Firebase${RESET}"
fi

# Fix CRLF from Windows
run_cmd "Fix CRLF en scripts" "$LINENO" "find /etc/movivip -name '*.sh' -type f -exec sed -i 's/\r$//' {} + 2>/dev/null"

# Guardar commit hash si existe .git
COMMIT_HASH_FILE="/etc/movivip/.last_commit_hash"
if [[ -d /etc/movivip/.git ]]; then
    REMOTE_SHA=$(cd /etc/movivip && git rev-parse HEAD 2>/dev/null)
    [[ -n "$REMOTE_SHA" ]] && echo "$REMOTE_SHA" > "$COMMIT_HASH_FILE" && chmod 600 "$COMMIT_HASH_FILE"
fi

# Verificar instalación completa
run_cmd "Verificando archivos críticos" "$LINENO" "
    for f in menu.sh config.conf protocolos/slowdns.sh protocolos/dropbear.sh protocolos/bot.sh protocolos/ssl.sh protocolos/v2ray.sh protocolos/wireguard.sh protocolos/openssh.sh protocolos/udpcustom.sh protocolos/zipvpn.sh protocolos/hysteria.sh protocolos/systemdns.sh protocolos/xhttp.sh protocolos/bhttp.sh protocolos/btun.sh protocolos/shadowsocks.sh protocolos/payload.sh protocolos/openvpn.sh protocolos/socks5.sh protocolos/hcr.sh protocolos/hcr protocolos/hcr-amd64 languages/lang.sh; do
        [[ -f /etc/movivip/\$f ]] || { echo \"FALTA: \$f\"; exit 1; }
    done
"

echo -e "      ${GREEN}✔ Archivos críticos verificados${RESET}"

#==============================
# SELECTOR DE PROTOCOLOS
#==============================

echo -e "      ${CYAN}→ Actualizando repositorios antes de protocolos...${RESET}"
pkg_update >/dev/null 2>&1

CONFIG="/etc/movivip/config.conf"

install_dropbear() {
    echo ""
    echo -e "      ${CYAN}→ Instalando Dropbear (puertos 90,143,109)...${RESET}"
    local DROPBEAR_PORTS="90,143,109"

    pkg_update >/dev/null 2>&1
    run_cmd "Instalando paquetes dropbear" "$LINENO" "pkg_install dropbear dropbear-bin"
    # Fix Ubuntu default config — NO_START=1 blocks service
    if [[ -f /etc/default/dropbear ]]; then
        sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
        sed -i 's/DROPBEAR_PORT=.*/DROPBEAR_PORT=0/' /etc/default/dropbear
    fi
    # Verify binary exists (dropbear-bin provides /usr/sbin/dropbear)
    if [[ ! -x /usr/sbin/dropbear ]]; then
        run_cmd "Reinstalando dropbear-bin (binario faltante)" "$LINENO" "pkg_remove dropbear-bin; pkg_install dropbear-bin"
        [[ ! -x /usr/sbin/dropbear ]] && {
            echo -e "      ${RED}✘ No se pudo instalar /usr/sbin/dropbear${RESET}"
            return 1
        }
    fi

    if [[ -f "$BASE/herramientas/openports.sh" ]]; then
        source "$BASE/herramientas/openports.sh"
        open_ports "TCP:90,143,109"
    else
        sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
        for P in 90 143 109; do
            iptables -C INPUT -p tcp --dport "$P" -j ACCEPT 2>/dev/null \
                || iptables -A INPUT -p tcp --dport "$P" -j ACCEPT
        done
        DEV=$(ip -4 route show default | awk '{print $5}' | head -1)
        [[ -n "$DEV" ]] && {
            iptables -t nat -C POSTROUTING -o "$DEV" -j MASQUERADE 2>/dev/null \
                || iptables -t nat -A POSTROUTING -o "$DEV" -j MASQUERADE
        }
    fi

    mkdir -p /etc/dropbear
    [[ ! -f /etc/dropbear/dropbear_rsa_host_key ]] && \
        dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key >/dev/null 2>&1
    [[ ! -f /etc/dropbear/dropbear_ecdsa_host_key ]] && \
        dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key >/dev/null 2>&1
    [[ ! -f /etc/dropbear/dropbear_ed25519_host_key ]] && \
        dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key >/dev/null 2>&1

    # Fix banner: dropbear falla si -b /etc/issue.net no existe
    # (en VPS fresco el auto-repair lo borra; el banner se crea al final)
    if [[ ! -f /etc/issue.net ]]; then
        printf 'MoviVIP Network\n' > /etc/issue.net
    fi

    systemctl stop dropbear 2>/dev/null
    systemctl disable dropbear 2>/dev/null

    local EXEC="/usr/sbin/dropbear -F"
    IFS=',' read -ra PORT_ARRAY <<< "$DROPBEAR_PORTS"
    for PORT in "${PORT_ARRAY[@]}"; do
        EXEC="$EXEC -p $PORT"
    done
    EXEC="$EXEC -W 65536 -b /etc/issue.net"

cat > /etc/systemd/system/dropbear_custom.service <<DEOF
[Unit]
Description=MoviVIP Dropbear Multi-Port
After=network.target

[Service]
Type=simple
ExecStart=$EXEC
Restart=always
RestartSec=3
KillMode=process

[Install]
WantedBy=multi-user.target
DEOF

    run_cmd "Activando dropbear_custom" "$LINENO" "systemctl daemon-reload; systemctl enable dropbear_custom; systemctl restart dropbear_custom"
    if systemctl is-active --quiet dropbear_custom; then
        sed -i 's/^DROPBEAR=.*/DROPBEAR=ON/' "$CONFIG" 2>/dev/null
        grep -q "^DROPBEAR_PORT=" "$CONFIG" 2>/dev/null \
            && sed -i "s/^DROPBEAR_PORT=.*/DROPBEAR_PORT=\"$DROPBEAR_PORTS\"/" "$CONFIG" \
            || echo "DROPBEAR_PORT=\"$DROPBEAR_PORTS\"" >> "$CONFIG"
        echo -e "      ${GREEN}✔${RESET} Dropbear ON (puertos $DROPBEAR_PORTS)"
    else
        echo -e "      ${RED}✖${RESET} Dropbear no inició — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "Dropbear start" "systemctl restart dropbear_custom" "Service did not start"
        # Diagnóstico real para soporte
        systemctl status dropbear_custom --no-pager -l 2>/dev/null | tail -8
        journalctl -u dropbear_custom -n 8 --no-pager 2>/dev/null | tail -8
        echo ""
    fi
}

install_badvpn() {
    echo ""
    echo -e "      ${CYAN}→ Instalando BadVPN UDPGW (puertos 7200,7300)...${RESET}"
    local BIN="/usr/local/bin/badvpn-udpgw"

    if [[ -f "$BASE/herramientas/openports.sh" ]]; then
        source "$BASE/herramientas/openports.sh"
        open_ports "UDP:7200,7300"
    else
        sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
        for P in 7200 7300; do
            iptables -C INPUT -p udp --dport "$P" -j ACCEPT 2>/dev/null \
                || iptables -A INPUT -p udp --dport "$P" -j ACCEPT
        done
        DEV=$(ip -4 route show default | awk '{print $5}' | head -1)
        [[ -n "$DEV" ]] && {
            iptables -t nat -C POSTROUTING -o "$DEV" -j MASQUERADE 2>/dev/null \
                || iptables -t nat -A POSTROUTING -o "$DEV" -j MASQUERADE
        }
    fi

    run_cmd "Instalando dependencias build" "$LINENO" "pkg_update >/dev/null 2>&1 && pkg_install git cmake build-essential"
    # Descarga TARBALL (1 GET HTTP) en vez de git clone: más fiable frente a rate-limit, con 3 reintentos
    run_cmd "Descargando badvpn (tarball)" "$LINENO" "rm -rf /tmp/badvpn /tmp/badvpn.tar.gz; mkdir -p /tmp/badvpn; for i in 1 2 3; do curl -fsSL 'https://github.com/ambrop72/badvpn/archive/refs/heads/master.tar.gz' -o /tmp/badvpn.tar.gz && break; sleep 5; done; tar -xzf /tmp/badvpn.tar.gz -C /tmp/badvpn --strip-components=1"
    run_cmd "Compilando badvpn" "$LINENO" "cd /tmp/badvpn && mkdir -p build && cd build && cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >/dev/null 2>&1 && make -j\$(nproc) >/dev/null 2>&1"
    run_cmd "Copiando binario" "$LINENO" "test -f /tmp/badvpn/build/udpgw/badvpn-udpgw && cp /tmp/badvpn/build/udpgw/badvpn-udpgw $BIN && chmod +x $BIN && rm -rf /tmp/badvpn /tmp/badvpn.tar.gz"
    if [[ ! -f "$BIN" ]]; then
        echo -e "      ${RED}✖${RESET} BadVPN: binario no disponible — no se crean servicios para evitar restart-loop"
        log_error "$LINENO" "BadVPN binary" "cmake/make" "badvpn-udpgw not built"
        return
    fi

    cat > /etc/systemd/system/badvpn-udpgw-7300.service <<SEOF1
[Unit]
Description=BadVPN UDPGW Puerto 7300 (Juegos)
After=network.target

[Service]
Type=simple
ExecStart=$BIN --listen-addr 0.0.0.0:7300 --max-clients 999 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SEOF1

    cat > /etc/systemd/system/badvpn-udpgw-7200.service <<SEOF2
[Unit]
Description=BadVPN UDPGW Puerto 7200 (VoIP)
After=network.target

[Service]
Type=simple
ExecStart=$BIN --listen-addr 0.0.0.0:7200 --max-clients 999 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SEOF2

    run_cmd "Activando servicios BadVPN" "$LINENO" "systemctl daemon-reload; systemctl enable badvpn-udpgw-7300 badvpn-udpgw-7200; systemctl restart badvpn-udpgw-7300 badvpn-udpgw-7200"
    if systemctl is-active --quiet badvpn-udpgw-7300 && systemctl is-active --quiet badvpn-udpgw-7200; then
        sed -i 's/^BADVPN=.*/BADVPN=ON/' "$CONFIG" 2>/dev/null
        echo -e "      ${GREEN}✔${RESET} BadVPN ON (puertos 7200,7300)"
    else
        echo -e "      ${RED}✖${RESET} BadVPN no inició — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "BadVPN start" "systemctl restart badvpn-udpgw" "Service did not start"
    fi
}

install_udpcustom() {
    echo ""
    echo -e "      ${CYAN}→ Instalando UDP Custom (puerto 36712)...${RESET}"

    run_cmd "Instalando dependencias UDP Custom" "$LINENO" "pkg_install curl wget iptables libpam0g"

    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

    if [[ -f "$BASE/herramientas/openports.sh" ]]; then
        source "$BASE/herramientas/openports.sh"
        open_ports "UDP:1-36712"
    else
        iptables -C INPUT -p udp --dport 1:36712 -j ACCEPT 2>/dev/null \
            || iptables -A INPUT -p udp --dport 1:36712 -j ACCEPT
        DEV=$(ip -4 route show default | awk '{print $5}' | head -1)
        [[ -n "$DEV" ]] && {
            iptables -t nat -C POSTROUTING -o "$DEV" -j MASQUERADE 2>/dev/null \
                || iptables -t nat -A POSTROUTING -o "$DEV" -j MASQUERADE
        }
    fi

    local ARCH URL
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  URL="https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-amd64" ;;
        aarch64) URL="https://github.com/Depwisescript/UDP/raw/main/udp-custom-linux-arm" ;;
        *) echo -e "      ${RED}✖${RESET} Arquitectura $ARCH no soportada"; return ;;
    esac

    run_cmd "Descargando UDP Custom binario" "$LINENO" "curl -L -s -f '$URL' -o /usr/bin/udp && chmod +x /usr/bin/udp"
    if [[ ! -f /usr/bin/udp ]]; then
        echo -e "      ${RED}✖${RESET} Error descargando UDP Custom"
        log_error "$LINENO" "UDP Custom download" "curl -L $URL" "Binary not found"
        return
    fi

    cat > /usr/bin/config.json <<'UEOF'
{
    "listen": ":36712",
    "stream_buffer": 33554432,
    "receive_buffer": 83886080,
    "auth": {
        "mode": "passwords"
    }
}
UEOF

    cat > /etc/systemd/system/udp-custom.service <<'UEOF2'
[Unit]
Description=UDP Custom Server MoviVIP
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/bin
ExecStart=/usr/bin/udp server -exclude 2200,7300,7200,7100,323,10008,10004,5667 /usr/bin/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UEOF2

    run_cmd "Activando UDP Custom" "$LINENO" "systemctl daemon-reload; systemctl enable udp-custom; systemctl start udp-custom"
    if systemctl is-active --quiet udp-custom; then
        sed -i 's/^UDP_CUSTOM=.*/UDP_CUSTOM=ON/' "$CONFIG" 2>/dev/null
        grep -q "^UDP_CUSTOM_PORT=" "$CONFIG" 2>/dev/null || echo "UDP_CUSTOM_PORT=36712" >> "$CONFIG"
        echo -e "      ${GREEN}✔${RESET} UDP Custom ON (puerto 36712)"
    else
        echo -e "      ${RED}✖${RESET} UDP Custom no inició — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "UDP Custom start" "systemctl start udp-custom" "Service did not start"
    fi
}

install_v2ray() {
    echo ""
    echo -e "      ${CYAN}→ Instalando V2Ray/Xray...${RESET}"
    local XRAY_CFG="/usr/local/etc/xray/config.json"

    run_cmd "Instalando dependencias V2Ray" "$LINENO" "pkg_update >/dev/null 2>&1 && pkg_install curl unzip jq socat cron"
    run_cmd "Descargando script Xray" "$LINENO" "curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh -o /tmp/xray-install.sh && chmod +x /tmp/xray-install.sh"
    run_cmd "Instalando Xray core" "$LINENO" "bash /tmp/xray-install.sh install"

    if [[ ! -f /usr/local/bin/xray ]]; then
        echo -e "      ${RED}✖${RESET} Error instalando Xray — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "Xray install" "xray-install" "Binary not found"
        return
    fi

    mkdir -p /usr/local/etc/xray /var/log/xray
    touch /var/log/xray/access.log

    # FIX v6.5: si hay config preservado con usuarios, restaurarlo en vez de crear vacío
    if [[ ! -f "$XRAY_CFG" && -f "$PRESERVED_DIR/xray-config.json" ]] \
        && jq -e '[.inbounds[].settings.clients[]?] | length > 0' "$PRESERVED_DIR/xray-config.json" >/dev/null 2>&1; then
        cp -f "$PRESERVED_DIR/xray-config.json" "$XRAY_CFG" 2>/dev/null
        chmod 644 "$XRAY_CFG" 2>/dev/null
        local _nuser
        _nuser=$(jq -r '[.inbounds[].settings.clients[]?] | length' "$XRAY_CFG" 2>/dev/null || echo 0)
        echo -e "      ${GREEN}✔${RESET} Xray: config con ${WHITE}$_nuser${RESET} usuarios preservados restaurado"
    fi

    if [[ ! -f "$XRAY_CFG" ]]; then
        cat > "$XRAY_CFG" <<'XEOF'
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log"
  },
  "api": {
    "tag": "api",
    "listen": "127.0.0.1:10085",
    "services": ["HandlerService","LoggerService","StatsService"]
  },
  "stats": {},
  "policy": {
    "levels": { "0": { "statsUserUplink": true, "statsUserDownlink": true } },
    "system": { "statsInboundUplink": true, "statsInboundDownlink": true }
  },
  "inbounds": [
    {
      "tag": "vmess-in",
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": { "clients": [] },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vmess" }
      },
      "sniffing": { "enabled": true, "destOverride": ["http","tls"] }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  ],
  "routing": {
    "rules": [
      { "type": "field", "inboundTag": ["api"], "outboundTag": "api" }
    ]
  }
}
XEOF
        echo -e "      ${CYAN}  → Configuración Xray creada (vmess en 127.0.0.1:10002)${RESET}"
    fi

    run_cmd "Activando Xray" "$LINENO" "systemctl enable xray; systemctl restart xray"
    if systemctl is-active --quiet xray; then
        sed -i 's/^V2RAY=.*/V2RAY=ON/' "$CONFIG" 2>/dev/null
        echo -e "      ${GREEN}✔${RESET} V2Ray/Xray ON (vmess en puerto 10002)"
    else
        sed -i 's/^V2RAY=.*/V2RAY=ON/' "$CONFIG" 2>/dev/null
        echo -e "      ${GRAY}  ⚠️ Xray instalado, configura desde Menú → Protocolos → V2Ray${RESET}"
    fi
}

install_zipvpn() {
    echo ""
    echo -e "      ${CYAN}→ Instalando ZiVPN...${RESET}"

    run_cmd "Instalando dependencias ZiVPN" "$LINENO" "pkg_install curl wget jq openssl iptables"

    sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

    local ARCH BIN_URL
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)          BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64" ;;
        aarch64|arm64)   BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm64" ;;
        armv7l|armv6l)   BIN_URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-arm" ;;
        *) echo -e "      ${RED}✖${RESET} Arquitectura $ARCH no soportada"; return ;;
    esac

    mkdir -p /etc/zivpn

    run_cmd "Descargando ZiVPN binario" "$LINENO" "curl -L --retry 3 --connect-timeout 10 '$BIN_URL' -o /usr/local/bin/zivpn && chmod +x /usr/local/bin/zivpn"
    if [[ ! -f /usr/local/bin/zivpn ]]; then
        echo -e "      ${RED}✖${RESET} Error descargando ZiVPN"
        log_error "$LINENO" "ZiVPN download" "curl -L $BIN_URL" "Binary not found"
        return
    fi

    run_cmd "Generando certificados SSL ZiVPN" "$LINENO" "openssl req -new -newkey rsa:4096 -nodes -x509 -days 3650 -subj '/C=US/ST=CA/L=LA/O=ZiVPN/CN=zivpn' -keyout /etc/zivpn/zivpn.key -out /etc/zivpn/zivpn.crt 2>/dev/null"

    local ZPORT=5667

    # FIX v6.5: NO pisar config existente con passwords reales.
    # Si /etc/zivpn/config.json ya existe con usuarios, preservarlo
    # (solo regenerar listen/cert si hace falta suavemente).
    if [[ -f /etc/zivpn/config.json ]] && jq -e '.auth.config | length > 1' /etc/zivpn/config.json >/dev/null 2>&1; then
        local _npass
        _npass=$(jq -r '.auth.config | length' /etc/zivpn/config.json 2>/dev/null || echo 0)
        echo -e "      ${GREEN}✔${RESET} ZiVPN: config existente conservada (${WHITE}$_npass${RESET} passwords preservados)"
        # Asegurar listen correcto sin tocar auth.config
        if ! jq -e --arg l ":$ZPORT" '.listen == $l' /etc/zivpn/config.json >/dev/null 2>&1; then
            jq --arg l ":$ZPORT" '.listen = $l' /etc/zivpn/config.json > /tmp/zivpn-cfg.json.$$ 2>/dev/null \
                && mv /tmp/zivpn-cfg.json.$$ /etc/zivpn/config.json 2>/dev/null
        fi
    elif [[ -f /etc/zivpn/config.json ]] && jq -e '.auth.config | length == 1' /etc/zivpn/config.json >/dev/null 2>&1; then
        # Config placeholder sin usuarios reales: buscar presevado y restaurarlo
        if [[ -f "$PRESERVED_DIR/zivpn-config.json" ]]; then
            cp -f "$PRESERVED_DIR/zivpn-config.json" /etc/zivpn/config.json 2>/dev/null
            chmod 600 /etc/zivpn/config.json 2>/dev/null
            echo -e "      ${GREEN}✔${RESET} ZiVPN: usuarios preservados restaurados desde backup"
        else
            cat > /etc/zivpn/config.json <<ZEOF
{
    "listen": ":$ZPORT",
    "cert": "/etc/zivpn/zivpn.crt",
    "key": "/etc/zivpn/zivpn.key",
    "max_conn": 0,
    "auth": {
        "mode": "passwords",
        "config": ["1"]
    }
}
ZEOF
        fi
    else
        cat > /etc/zivpn/config.json <<ZEOF
{
    "listen": ":$ZPORT",
    "cert": "/etc/zivpn/zivpn.crt",
    "key": "/etc/zivpn/zivpn.key",
    "max_conn": 0,
    "auth": {
        "mode": "passwords",
        "config": ["1"]
    }
}
ZEOF
    fi

    cat > /etc/systemd/system/zivpn.service <<ZEOF2
[Unit]
Description=ZiVPN UDP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=2
LimitNOFILE=1048576
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW

[Install]
WantedBy=multi-user.target
ZEOF2

    chmod 600 /etc/zivpn/config.json /etc/zivpn/zivpn.key
    chmod 644 /etc/zivpn/zivpn.crt

    local DEV
    DEV=$(ip route 2>/dev/null | awk '/default/ {print $5; exit}')
    [[ -z "$DEV" ]] && DEV=$(ip link show up 2>/dev/null | awk -F': ' '/state UP/ && $2!="lo"{print $2;exit}')

    if [[ -n "$DEV" ]]; then
        iptables -t nat -I PREROUTING 1 -p udp --dport 6000:19999 -j DNAT --to-destination :"$ZPORT" 2>/dev/null
        iptables -A INPUT -p udp --dport "$ZPORT" -j ACCEPT 2>/dev/null
    fi

    run_cmd "Activando ZiVPN" "$LINENO" "systemctl daemon-reload; systemctl enable zivpn; systemctl restart zivpn"
    if systemctl is-active --quiet zivpn; then
        sed -i 's/^ZIPVPN=.*/ZIPVPN=ON/' "$CONFIG" 2>/dev/null
        grep -q "^ZIPVPN_PORT=" "$CONFIG" 2>/dev/null \
            && sed -i "s/^ZIPVPN_PORT=.*/ZIPVPN_PORT=\"$ZPORT\"/" "$CONFIG" \
            || echo "ZIPVPN_PORT=\"$ZPORT\"" >> "$CONFIG"
        echo -e "      ${GREEN}✔${RESET} ZiVPN ON (puerto $ZPORT, rango 6000:19999→$ZPORT)"
    else
        echo -e "      ${RED}✖${RESET} ZiVPN no inició — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "ZiVPN start" "systemctl restart zivpn" "Service did not start"
    fi
}

install_slowdns() {
    echo ""
    echo -e "      ${CYAN}→ SlowDNS: instalación completa (dominio + DNS + servicio)...${RESET}"

    # 1) Determinar el Dominio del túnel (SlowDNS)
    # Fuentes: env SLOWDNS_DOMAIN > CF_SUB_FQDN (subdominio Cloudflare creado) >
    #          /etc/slowdns/domain.conf previo > prompt interactivo
    local SD_DOMAIN=""
    if [[ -f "$BASE/cf.conf" ]]; then
        # shellcheck disable=SC1091
        source "$BASE/cf.conf"
        export CF_EMAIL CF_KEY CF_SUB_FQDN 2>/dev/null || true
    fi
    if [[ -n "${SLOWDNS_DOMAIN:-}" ]]; then
        SD_DOMAIN="$SLOWDNS_DOMAIN"
        # v7.3.13: si viene sin prefijo ns. (ej: freenet.movivipoppax.uk), anteponerlo
        [[ "$SD_DOMAIN" != ns.* ]] && SD_DOMAIN="ns.$SD_DOMAIN"
    elif [[ -n "${CF_SUB_FQDN:-}" ]]; then
        SD_DOMAIN="$(echo "$CF_SUB_FQDN" | tr -d ' ')"
        # v7.3.13: usar lo que ya escogiste en Cloudflare como túnel NS (ej: freenet.movivipoppax.uk → ns.freenet.movivipoppax.uk)
        [[ "$SD_DOMAIN" != ns.* ]] && SD_DOMAIN="ns.$SD_DOMAIN"
        echo -e "      ${GREEN}  ✔ SlowDNS usará tu subdominio Cloudflare: ${WHITE}$SD_DOMAIN${RESET} (crea A + NS automáticos)"
    elif [[ -f /etc/slowdns/domain.conf ]] && [[ -s /etc/slowdns/domain.conf ]]; then
        SD_DOMAIN="$(cat /etc/slowdns/domain.conf)"
    else
        if [[ "$AUTO_INSTALL" == "1" ]] && [[ -z "${SLOWDNS_DOMAIN:-}" ]]; then
            echo -e "      ${GRAY}ℹ️  Modo automático: se omite SlowDNS (requiere dominio NS).${RESET}"
            sleep 1
            return
        fi
        echo ""
        read -rp "$(trx '🌐 Dominio NS (Ej: ns.midominio.com): ')" SD_DOMAIN
        SD_DOMAIN="${SD_DOMAIN// /}"
    fi
    [[ -z "$SD_DOMAIN" ]] && {
        echo -e "      ${RED}✖${RESET} Dominio inválido. No se instaló SlowDNS."
        sleep 2
        return
    }
    export SLOWDNS_DOMAIN="$SD_DOMAIN"

    # 3) Opción para configurar DNS en Cloudflare ahora (A + NS automáticos)
    # Solo se pregunta si hay TTY y NO hay credenciales ya disponibles.
    if [[ -t 0 ]] && [[ -z "${CF_EMAIL:-}" || -z "${CF_KEY:-}" ]]; then
        local CF_AUTO_ASK=""
        read -rp "$(trx '🌐 Configurar DNS en Cloudflare? (s/n): ')" CF_AUTO_ASK
        if [[ "$CF_AUTO_ASK" =~ ^[Ss]$ ]]; then
            [[ -z "${CF_EMAIL:-}" ]] && read -rp "$(trx '   Email Cloudflare: ')" CF_EMAIL
            [[ -z "${CF_KEY:-}" ]]  && read -rp "$(trx '   Global API Key: ')" CF_KEY
            if [[ -n "$CF_EMAIL" && -n "$CF_KEY" ]]; then
                mkdir -p "$BASE"
                cat > "$BASE/cf.conf" <<CFEOF
CF_EMAIL="$CF_EMAIL"
CF_KEY="$CF_KEY"
CFEOF
                chmod 600 "$BASE/cf.conf"
                export CF_EMAIL CF_KEY
                echo -e "      ${GREEN}  ✔ Credenciales guardadas (usa SlowDNS automático).${RESET}"
            else
                echo -e "      ${GRAY}  ⚠️  Credenciales incompletas — se configurará manualmente.${RESET}"
            fi
        fi
    fi

    # 4) Delegar la instalación completa al script especializado
    # (pide/usa SLOWDNS_DOMAIN, cf_ensure_ns, binario, claves, servicio systemd,
    #  puerto 53, test funcional e instrucciones manuales si no hay CF)
    if [[ ! -x "$BASE/protocolos/slowdns.sh" ]]; then
        echo -e "      ${RED}✖${RESET} No se encuentra protocolos/slowdns.sh"
        return
    fi

    bash "$BASE/protocolos/slowdns.sh" --install
    local RC=$?
    if [[ $RC -ne 0 ]]; then
        echo -e "      ${RED}✖${RESET} SlowDNS no completó (código $RC)."
        echo -e "      ${GRAY}  Reintenta desde Menú → Protocolos → SlowDNS.${RESET}"
    else
        sed -i 's/^SLOWDNS=.*/SLOWDNS=ON/' "$CONFIG" 2>/dev/null
        echo -e "      ${GREEN}✔${RESET} SlowDNS instalado y configurado con dominio: ${WHITE}$SD_DOMAIN${RESET}"
    fi
}

install_hysteria() {
    echo ""
    echo "$(trx '⚡ Instalando Hysteria [UDP QUIC]...')"
    HY_DIR="/etc/hysteria"
    HY_BIN="/usr/local/bin/hysteria1"
    HY_CONFIG="$HY_DIR/config.json"
    HY_CERT="$HY_DIR/server.crt"
    HY_KEY="$HY_DIR/server.key"
    HY_SERVICE="/etc/systemd/system/hysteria1-server.service"
    HY_VERSION="v1.3.5"
    run_cmd "Dependencias Hysteria" "$LINENO" "pkg_install curl wget openssl ca-certificates"
    mkdir -p "$HY_DIR"

    run_cmd "Descargando Hysteria $HY_VERSION" "$LINENO" "
        ARCH=\$(uname -m)
        case \"\$ARCH\" in
            x86_64)      BIN_NAME='hysteria-linux-amd64' ;;
            aarch64|arm64) BIN_NAME='hysteria-linux-arm64' ;;
            armv7l|armv6l) BIN_NAME='hysteria-linux-arm' ;;
            s390x)       BIN_NAME='hysteria-linux-s390x' ;;
            *)           echo 'Arquitectura no soportada'; exit 1 ;;
        esac
        rm -f \"$HY_BIN\"
        for URL in \"https://github.com/apernet/hysteria/releases/download/${HY_VERSION}/\${BIN_NAME}\" \"https://ghproxy.net/https://github.com/apernet/hysteria/releases/download/${HY_VERSION}/\${BIN_NAME}\" \"https://gh-proxy.com/https://github.com/apernet/hysteria/releases/download/${HY_VERSION}/\${BIN_NAME}\"; do
            curl -L -s -f --max-time 120 \"\$URL\" -o \"$HY_BIN\" && chmod +x \"$HY_BIN\" && \"$HY_BIN\" -v >/dev/null 2>&1 && break
            rm -f \"$HY_BIN\"
        done
        test -x \"$HY_BIN\"
    "
    if [[ ! -x "$HY_BIN" ]]; then
        echo -e "      ${RED}✖${RESET} Hysteria no descargado — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "Hysteria binary" "curl download" "Binary download failed"
        return 1
    fi

    # Dominio (de config o hostname)
    HY_DOMAIN=$(sed -n 's/^SERVER_DOMAIN=//p' "$CONFIG" 2>/dev/null | tail -1 | tr -d '"')
    [[ -z "$HY_DOMAIN" ]] && HY_DOMAIN=$(hostname -f 2>/dev/null || echo 'ssl-tunnel')
    # Puerto/credenciales: REUTILIZAR los del config.conf si ya existen (v8.2.9 fix)
    # → instalación preconfigurada mantiene HYSTERIA_PORT=36721, AUTH y OBFS estables.
    # → SIEMPRE respetar HYSTERIA_PORT del config; solo generar si falta/inválido.
    HY_PORT_CFG=$(sed -n 's/^HYSTERIA_PORT=//p' "$CONFIG" 2>/dev/null | tail -1 | tr -d '"')
    HY_AUTH_CFG=$(sed -n 's/^HYSTERIA_AUTH=//p' "$CONFIG" 2>/dev/null | tail -1 | tr -d '"')
    HY_OBFS_CFG=$(sed -n 's/^HYSTERIA_OBFS=//p' "$CONFIG" 2>/dev/null | tail -1 | tr -d '"')
    if [[ -n "$HY_PORT_CFG" ]] && [[ "$HY_PORT_CFG" =~ ^[0-9]+$ ]]; then
        HY_PORT="$HY_PORT_CFG"
    else
        # Puerto random validado (solo cuando el config no trae puerto asignado)
        HY_PORT=$((RANDOM % 55000 + 10000))
        for RESERVED in 22 53 80 443 2100 5300 5353 5354 5355 5380 5667 7200 7300 9900 8080 8443 10015 10002; do
            [[ "$HY_PORT" == "$RESERVED" ]] && HY_PORT=$((RANDOM % 55000 + 10000))
        done
    fi
    [[ -n "$HY_AUTH_CFG" ]] && HY_AUTH="$HY_AUTH_CFG" || HY_AUTH=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c16)
    [[ -n "$HY_OBFS_CFG" ]] && HY_OBFS="$HY_OBFS_CFG" || HY_OBFS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c16)

    run_cmd "Generando certificado Hysteria" "$LINENO" "
        openssl ecparam -genkey -name prime256v1 -out $HY_KEY >/dev/null 2>&1
        openssl req -new -x509 -days 36500 -nodes -key $HY_KEY -out $HY_CERT -subj '/CN=$HY_DOMAIN' >/dev/null 2>&1
        chmod 600 $HY_KEY; chmod 644 $HY_CERT
    "
    cat > "$HY_CONFIG" <<EOF
{
"protocol":"udp",
"listen":":${HY_PORT}",
"obfs":"${HY_OBFS}",
"cert":"${HY_CERT}",
"key":"${HY_KEY}",
"alpn":"h3",
"auth":{
"mode":"password",
"config":{
"password":"${HY_AUTH}"
}
}
}
EOF
    cat > "$HY_SERVICE" <<'SVCEOF'
[Unit]
Description=MoviVIP Hysteria Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/hysteria1 -config /etc/hysteria/config.json server
Restart=always
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SVCEOF
    run_cmd "Habilitando Hysteria" "$LINENO" "systemctl daemon-reload && systemctl enable --now hysteria1-server"

    # Firewall: abrir UDP + blindaje anti-DNAT
    iptables -C INPUT -p udp --dport "$HY_PORT" -j ACCEPT 2>/dev/null || iptables -A INPUT -p udp --dport "$HY_PORT" -j ACCEPT
    while iptables -t nat -C PREROUTING -p udp --dport "$HY_PORT" -j RETURN 2>/dev/null; do
        iptables -t nat -D PREROUTING -p udp --dport "$HY_PORT" -j RETURN
    done
    iptables -t nat -I PREROUTING 1 -p udp --dport "$HY_PORT" -j RETURN
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null

    sed -i 's/^HYSTERIA=.*/HYSTERIA=ON/' "$CONFIG" 2>/dev/null
    sed -i '/^HYSTERIA_PORT=/d; /^HYSTERIA_AUTH=/d; /^HYSTERIA_OBFS=/d' "$CONFIG" 2>/dev/null
    { echo "HYSTERIA_PORT=$HY_PORT"; echo "HYSTERIA_AUTH=$HY_AUTH"; echo "HYSTERIA_OBFS=$HY_OBFS"; } >> "$CONFIG"

    if systemctl is-active --quiet hysteria1-server; then
        echo -e "      ${GREEN}✔${RESET} Hysteria ON (UDP $HY_PORT)"
    else
        echo -e "      ${RED}✖${RESET} Hysteria no inició — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "Hysteria start" "systemctl restart hysteria1-server" "Service did not start"
    fi
}

install_wireguard() {
    echo ""
    echo "$(trx '🔒 Instalando WireGuard VPN...')"
    WG_IF="wg0"
    WG_DIR="/etc/wireguard"
    WG_SRV_CONF="$WG_DIR/${WG_IF}.conf"
    WG_NET="10.66.66"
    WG_PORT="${WG_PORT:-51820}"
    PEERS_DIR="$BASE/wg-peers"
    mkdir -p "$PEERS_DIR" "$WG_DIR"

    run_cmd "Instalando wireguard-tools y qrencode" "$LINENO" "pkg_install wireguard wireguard-tools qrencode; modprobe wireguard 2>/dev/null || true"
    command -v wg >/dev/null 2>&1 || { echo -e "      ${RED}✖${RESET} WireGuard no instalado — Reportar a soporte: línea $LINENO"; log_error "$LINENO" "WireGuard install" "pkg_install wireguard" "wg missing"; return 1; }

    if [[ ! -f "$WG_SRV_CONF" ]]; then
        umask 077
        WG_PRIV=$(wg genkey)
        WG_PUB=$(echo "$WG_PRIV" | wg pubkey)
        IFACE=$(ip route | awk '/default/{print $5; exit}')
        cat > "$WG_SRV_CONF" <<EOF
[Interface]
Address = ${WG_NET}.1/24
ListenPort = ${WG_PORT}
PrivateKey = ${WG_PRIV}
PostUp = iptables -A FORWARD -i ${WG_IF} -j ACCEPT -m comment --comment MOVIVIP-WG; iptables -A FORWARD -o ${WG_IF} -j ACCEPT -m comment --comment MOVIVIP-WG; iptables -t nat -A POSTROUTING -o ${IFACE} -j MASQUERADE -m comment --comment MOVIVIP-WG
PostDown = iptables -D FORWARD -i ${WG_IF} -j ACCEPT -m comment --comment MOVIVIP-WG; iptables -D FORWARD -o ${WG_IF} -j ACCEPT -m comment --comment MOVIVIP-WG; iptables -t nat -D POSTROUTING -o ${IFACE} -j MASQUERADE -m comment --comment MOVIVIP-WG
EOF
        grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf 2>/dev/null || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        sysctl -w net.ipv4.ip_forward=1 >/dev/null
        sed -i '/^WG=/d; /^WG_PORT=/d' "$CONFIG"
        { echo "WG=ON"; echo "WG_PORT=$WG_PORT"; } >> "$CONFIG"
        chmod 600 "$WG_SRV_CONF"
    fi
    run_cmd "Iniciando WireGuard wg0" "$LINENO" "systemctl enable --now wg-quick@$WG_IF"
    sleep 1
    if systemctl is-active --quiet wg-quick@$WG_IF; then
        sed -i 's/^WG=.*/WG=ON/' "$CONFIG" 2>/dev/null
        echo -e "      ${GREEN}✔${RESET} WireGuard ON (UDP $WG_PORT, red $WG_NET.0/24)"
    else
        echo -e "      ${RED}✖${RESET} WireGuard no inició — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "WireGuard start" "systemctl restart wg-quick@wg0" "Service did not start"
    fi
}

install_squid() {
    echo ""
    echo "$(trx '🐟 Instalando Squid Proxy...')"
    run_cmd "Instalando squid" "$LINENO" "pkg_install squid"
    run_cmd "Habilitando squid" "$LINENO" "systemctl enable squid"
    run_cmd "Iniciando squid" "$LINENO" "systemctl restart squid"
    if systemctl is-active --quiet squid; then
        sed -i 's/^SQUID=.*/SQUID=ON/' "$CONFIG" 2>/dev/null
        echo -e "      ${GREEN}✔${RESET} Squid Proxy ON (puerto 3128)"
    else
        echo -e "      ${RED}✖${RESET} Squid no inició — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "Squid start" "systemctl restart squid" "Service did not start"
    fi
}

install_webmin() {
    echo ""
    echo "$(trx '🖥️ Instalando Webmin...')"
    run_cmd "Instalando dependencias Webmin" "$LINENO" "pkg_install curl wget"
    run_cmd "Descargando repo Webmin" "$LINENO" "curl -o /tmp/webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh && sh /tmp/webmin-setup-repo.sh -f --stable"
    run_cmd "Instalando Webmin" "$LINENO" "pkg_install webmin; rm -f /tmp/webmin-setup-repo.sh"
    if systemctl is-active --quiet webmin 2>/dev/null; then
        sed -i 's/^WEBMIN=.*/WEBMIN=ON/' "$CONFIG" 2>/dev/null
        echo -e "      ${GREEN}✔${RESET} Webmin ON (puerto 10000)"
    else
        sed -i 's/^WEBMIN=.*/WEBMIN=ON/' "$CONFIG" 2>/dev/null
        echo -e "      ${GRAY}  ⚠️ Webmin instalado, puerto 10000${RESET}"
    fi
}

# --- DTunnel (DTProto Server) — FIX v7.1: opción 15 ---
install_dtunnel() {
    echo ""
    echo -e "      ${CYAN}→ Instalando DTunnel (DTProto Server)...${RESET}"
    if [[ -f "$BASE/protocolos/dtunnel.sh" ]]; then

        # ── Token oficial DTunnel: cada cliente coloca el suyo ──
        # DTProto valida el token ONLINE contra el servidor del equipo DTunnel.
        # Si ya hay DTUNNEL_TOKEN en config.conf no vuelve a preguntar.
        if ! grep -q '^DTUNNEL_TOKEN=.' "$CONFIG" 2>/dev/null; then
            echo ""
            echo -e "      ${CYAN}🔑 DTunnel requiere un TOKEN OFICIAL del equipo DTunnel.${RESET}"
            echo -e "      ${YELLOW}   • Consíguelo en la app oficial DTunnel / @DTunnelBOT.${RESET}"
            echo -e "      ${YELLOW}   • Cada cliente usa SU propio token (validado online).${RESET}"
            echo ""
            if [[ "$AUTO_INSTALL" == "1" ]]; then
                echo -e "      ${GRAY}ℹ️  Modo automático: se omite DTunnel (requiere token manual).${RESET}"
                sleep 1
                return
            fi
            read -rp "      Ingresa tu Token de DTunnel: " TK_TMP
            TK_TMP="$(printf '%s' "${TK_TMP:-}" | tr -d '[:space:]')"
            if [[ -n "$TK_TMP" ]]; then
                sed -i '/^DTUNNEL_TOKEN=/d' "$CONFIG" 2>/dev/null
                echo "DTUNNEL_TOKEN=$TK_TMP" >> "$CONFIG"
            fi
            echo ""
        fi

        bash "$BASE/protocolos/dtunnel.sh" --install 2>&1 | tail -30
        if grep -q '^DTUNNEL=ON' "$CONFIG" 2>/dev/null; then
            echo -e "      ${GREEN}✔${RESET} DTunnel ON"
        else
            echo -e "      ${RED}✘${RESET} DTunnel no se activó — revisar log"
        fi
    else
        echo -e "      ${RED}✘${RESET} dtunnel.sh no encontrado"
    fi
}

# --- SystemDNS (systemd-resolved) — FIX v7.1: opción 16 ---
install_systemdns() {
    echo ""
    echo -e "      ${CYAN}→ Instalando System DNS (systemd-resolved)...${RESET}"
    if [[ -f "$BASE/protocolos/systemdns.sh" ]]; then
        bash "$BASE/protocolos/systemdns.sh" --install 2>&1 | tail -30
        if grep -q '^SYSTEMDNS=ON' "$CONFIG" 2>/dev/null; then
            echo -e "      ${GREEN}✔${RESET} SystemDNS ON"
        else
            echo -e "      ${RED}✘${RESET} SystemDNS no se activó — revisar log"
        fi
    else
        echo -e "      ${RED}✘${RESET} systemdns.sh no encontrado"
    fi
}

# --- Bot Telegram — FIX v7.1: opción 17 ---
install_bot() {
    echo ""
    # AUTO_INSTALL: el bot requiere 2 tokens de BotFather + credenciales
    # Firebase (solo los conoce el cliente) → se omite y se configura luego
    # desde el menú principal (opción 17).
    if [[ "$AUTO_INSTALL" == "1" ]]; then
        echo -e "      ${GRAY}ℹ️  Modo automático: Bot Telegram requiere tokens manuales (BotFather).${RESET}"
        echo -e "      ${GRAY}   Se omite — configúralo después desde el menú (opción 17).${RESET}"
        sleep 1
        return
    fi
    echo -e "      ${CYAN}→ Instalando Bot Telegram...${RESET}"
    if [[ -f "$BASE/protocolos/bot.sh" ]]; then
        bash "$BASE/protocolos/bot.sh" --install 2>&1 | tail -30
        if systemctl is-active --quiet 'movivip-*-admin' 2>/dev/null; then
            echo -e "      ${GREEN}✔${RESET} Bot Telegram activo (movivip-*-admin)"
        else
            echo -e "      ${RED}✘${RESET} Bot no se inició — revisar log"
        fi
    else
        echo -e "      ${RED}✘${RESET} bot.sh no encontrado"
    fi
}

# --- XHTTP_S — opción 18 ---
install_xhttp() {
    echo ""
    echo -e "      ${CYAN}→ Instalando XHTTP_S (SSH-XHTTP TLS/HTTP2)...${RESET}"
    if [[ -f "$BASE/protocolos/xhttp.sh" ]]; then
        bash "$BASE/protocolos/xhttp.sh" --install 2>&1 | tail -30
        if grep -q '^XHTTP=ON' "$CONFIG" 2>/dev/null; then
            echo -e "      ${GREEN}✔${RESET} XHTTP_S ON"
        else
            echo -e "      ${RED}✘${RESET} XHTTP_S no se activó — revisar log"
        fi
    else
        echo -e "      ${RED}✘${RESET} xhttp.sh no encontrado"
    fi
}

# --- BHTTP v2 — opción 19 ---
install_bhttp() {
    echo ""
    echo -e "      ${CYAN}→ Instalando BHTTP v2 (SSH-HTTP/2 Bootstrap)...${RESET}"
    if [[ -f "$BASE/protocolos/bhttp.sh" ]]; then
        bash "$BASE/protocolos/bhttp.sh" --install 2>&1 | tail -30
        if grep -q '^BHTTP=ON' "$CONFIG" 2>/dev/null; then
            echo -e "      ${GREEN}✔${RESET} BHTTP v2 ON"
        else
            echo -e "      ${RED}✘${RESET} BHTTP no se activó — revisar log"
        fi
    else
        echo -e "      ${RED}✘${RESET} bhttp.sh no encontrado"
    fi
}

# --- BTUN — opción 20 ---
install_btun() {
    echo ""
    echo -e "      ${CYAN}→ Instalando BTUN (VPN TCP/UDP)...${RESET}"
    if [[ -f "$BASE/protocolos/btun.sh" ]]; then
        bash "$BASE/protocolos/btun.sh" --install 2>&1 | tail -30
        if grep -q '^BTUN=ON' "$CONFIG" 2>/dev/null; then
            echo -e "      ${GREEN}✔${RESET} BTUN ON"
        else
            echo -e "      ${RED}✘${RESET} BTUN no se activó — revisar log"
        fi
    else
        echo -e "      ${RED}✘${RESET} btun.sh no encontrado"
    fi
}

# --- Shadowsocks — opción 21 ---
install_shadowsocks() {
    echo ""
    echo -e "      ${CYAN}→ Instalando Shadowsocks (SOCKS5 cifrado)...${RESET}"
    if [[ -f "$BASE/protocolos/shadowsocks.sh" ]]; then
        bash "$BASE/protocolos/shadowsocks.sh" --install 2>&1 | tail -30
        if grep -q '^SHADOWSOCKS=ON' "$CONFIG" 2>/dev/null; then
            echo -e "      ${GREEN}✔${RESET} Shadowsocks ON"
        else
            echo -e "      ${RED}✘${RESET} Shadowsocks no se activó — revisar log"
        fi
    else
        echo -e "      ${RED}✘${RESET} shadowsocks.sh no encontrado"
    fi
}

# --- Payload servers — opción 22 ---
install_payload() {
    echo ""
    echo -e "      ${CYAN}→ Instalando Payload servers (5 túneles HTTP)...${RESET}"
    if [[ -f "$BASE/protocolos/payload.sh" ]]; then
        bash "$BASE/protocolos/payload.sh" --install 2>&1 | tail -30
        if grep -q '^PAYLOAD=ON' "$CONFIG" 2>/dev/null; then
            echo -e "      ${GREEN}✔${RESET} Payload ON"
        else
            echo -e "      ${RED}✘${RESET} Payload no se activó — revisar log"
        fi
    else
        echo -e "      ${RED}✘${RESET} payload.sh no encontrado"
    fi
}

# --- OpenVPN — opción 23 ---
install_openvpn() {
    echo ""
    echo -e "      ${CYAN}→ Instalando OpenVPN (VPN UDP autenticada)...${RESET}"
    if [[ -f "$BASE/protocolos/openvpn.sh" ]]; then
        bash "$BASE/protocolos/openvpn.sh" --install 2>&1 | tail -30
        if grep -q '^OPENVPN=ON' "$CONFIG" 2>/dev/null; then
            echo -e "      ${GREEN}✔${RESET} OpenVPN ON"
        else
            echo -e "      ${RED}✘${RESET} OpenVPN no se activó — revisar log"
        fi
    else
        echo -e "      ${RED}✘${RESET} openvpn.sh no encontrado"
    fi
}

# --- SOCKS5 — opción 24 ---
install_socks5() {
    echo ""
    echo -e "      ${CYAN}→ Instalando SOCKS5 (dante-server)...${RESET}"
    if [[ -f "$BASE/protocolos/socks5.sh" ]]; then
        bash "$BASE/protocolos/socks5.sh" --install 2>&1 | tail -30
        if grep -q '^SOCKS5=ON' "$CONFIG" 2>/dev/null; then
            echo -e "      ${GREEN}✔${RESET} SOCKS5 ON"
        else
            echo -e "      ${RED}✘${RESET} SOCKS5 no se activó — revisar log"
        fi
    else
        echo -e "      ${RED}✘${RESET} socks5.sh no encontrado"
    fi
}

# --- HCR — opción 25 (relay plain interno + handshake TLS por haproxy) ---
install_hcr() {
    echo -e "      ${CYAN}→ Instalando HCR (HTTP Core Relay · handshake haproxy)...${RESET}"
    if [[ -f "$BASE/protocolos/hcr.sh" ]]; then
        # Si haproxy no está activo, ssl.sh (opción 1) debe ir primero
        if ! systemctl is-active --quiet haproxy; then
            echo -e "      ${RED}✘${RESET} haproxy no activo — instale primero SSL/TLS [1]"
            return 1
        fi
        bash "$BASE/protocolos/hcr.sh" --install 2>&1 | tail -30
        if grep -q '^HCR=ON' "$CONFIG" 2>/dev/null; then
            echo -e "      ${GREEN}✔${RESET} HCR ON (443 SNI hcr)"
        else
            echo -e "      ${RED}✘${RESET} HCR no se activó — revisar log"
        fi
    else
        echo -e "      ${RED}✘${RESET} hcr.sh no encontrado"
    fi
}

# --- 3X-UI Panel - opción 26 ---
install_xui() {
    echo -e "      ${CYAN}→ Instalando 3X-UI Panel (XRay VMESS/VLESS/Trojan)...${RESET}"
    # PRE: haproxy activo (necesario para el SSL/IP 54323 y para que xray use 443/80)
    if ! systemctl is-active --quiet haproxy; then
        echo -e "      ${RED}✘${RESET} haproxy no activo — instale primero SSL/TLS [1]"
        return 1
    fi
    # 1) FIX timezone (causa raíz: sin tzdata/Asia/Shanghai el panel no arranca)
    run_cmd "Zona horaria Asia/Shanghai (x-ui)" "$LINENO" "
        DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata >/dev/null 2>&1
        ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
        echo 'Asia/Shanghai' > /etc/timezone
        dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1
    "
    # 2) Descargar/instalar binario x-ui (headless, sin instalador interactivo)
    if [[ ! -x /usr/local/x-ui/x-ui ]]; then
        run_cmd "Descargando 3X-UI v0.3.2" "$LINENO" "
            mkdir -p /usr/local/x-ui
            curl -L -s -f --max-time 180 \
                https://github.com/vaxilu/x-ui/releases/download/0.3.2/x-ui-linux-amd64.tar.gz \
                -o /tmp/x-ui.tar.gz || curl -L -s -f --max-time 180 \
                https://ghproxy.net/https://github.com/vaxilu/x-ui/releases/download/0.3.2/x-ui-linux-amd64.tar.gz \
                -o /tmp/x-ui.tar.gz
            tar -xzf /tmp/x-ui.tar.gz -C /usr/local/x-ui/
            chmod +x /usr/local/x-ui/x-ui 2>/dev/null
            chmod +x /usr/local/x-ui/bin/xray-linux-amd64 2>/dev/null || true
            test -x /usr/local/x-ui/x-ui
        "
        if [[ ! -x /usr/local/x-ui/x-ui ]]; then
            echo -e "      ${RED}✘${RESET} 3X-UI no descargado — Reportar a soporte: línea $LINENO"
            log_error "$LINENO" "x-ui download" "curl release" "Binary download failed"
            return 1
        fi
    fi
    # 3) Servicio systemd (estable, con WorkingDirectory correcto)
    cat > /etc/systemd/system/x-ui.service <<'XUIEOF'
[Unit]
Description=x-ui Service
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/x-ui/
ExecStart=/usr/local/x-ui/x-ui

[Install]
WantedBy=multi-user.target
XUIEOF
    run_cmd "Habilitando 3X-UI" "$LINENO" "systemctl daemon-reload && systemctl enable --now x-ui"
    sleep 2
    # 4) Puerto interno 54322 (evita conflicto sshd 54321) + credenciales admin
    /usr/local/x-ui/x-ui setting -port 54322 2>/dev/null
    /usr/local/x-ui/x-ui setting -username admin -password admin 2>/dev/null
    systemctl restart x-ui >/dev/null 2>&1
    sleep 2
    # 5) Firewall + HAProxy SSL por IP (panel público https://IP:54323)
    iptables -C INPUT -p tcp --dport 54322 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport 54322 -j ACCEPT
    iptables -C INPUT -p tcp --dport 54323 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport 54323 -j ACCEPT
    if [[ -f "$BASE/protocolos/xui.sh" ]]; then
        bash "$BASE/protocolos/xui.sh" haproxy 2>&1 | tail -5
    fi
    iptables-save > /etc/iptables/rules.v4 2>/dev/null
    # 6) Config
    sed -i 's/^XUI=.*/XUI=ON/' "$CONFIG" 2>/dev/null
    grep -q '^XUI=' "$CONFIG" 2>/dev/null || echo "XUI=ON" >> "$CONFIG"
    if systemctl is-active --quiet x-ui; then
        echo -e "      ${GREEN}✔${RESET} 3X-UI ON (panel https://$(curl -s4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'):54323 · interno 54322 · admin/admin)"
    else
        echo -e "      ${RED}✘${RESET} 3X-UI no inició — Reportar a soporte: línea $LINENO"
        log_error "$LINENO" "x-ui start" "systemctl start x-ui" "Service did not start"
    fi
}

# --- Menu de selección (ADAPTATIVO v6.3: pantallas pequeñas/móvil) ---
clear
# ── Ancho dinámico: tput cols real (móvil 40-57, Termux ~40), cap 30..62 ──
W=$(tput cols 2>/dev/null || echo 62)
[[ "$W" =~ ^[0-9]+$ ]] || W=62
(( W < 30 )) && W=30
(( W > 62 )) && W=62
HEADER="SELECCIONAR PROTOCOLOS A INSTALAR"
SEP=$(printf '━%.0s' $(seq 1 $W))
CTA="\033[1;96m"
CTB="\033[1;93m"
CTD="\033[1;97m"
CTG="\033[1;90m"
CTR="\033[0m"
CTG1="\033[1;92m"
CTE="\033[1;91m"

# Barra superior/separador adaptativo
echo -e "${CTA}╔$(printf '═%.0s' $(seq 1 $((W-2))))╗${CTR}"
echo -e "${CTA}║${CTR}${CTB}$(printf '%*s' $(((${#HEADER}+W-2)/2)) '')${HEADER}$(printf '%*s' $(((W-1-${#HEADER})/2)) '')${CTR}${CTA}║${CTR}"
echo -e "${CTA}╠$(printf '═%.0s' $(seq 1 $((W-2))))╣${CTR}"
echo -e "${CTA}║${CTR}${CTD}  Los marcados con ✅ ya están activos.${CTR}"
echo -e "${CTA}║${CTR}${CTD}  Escribe los números a instalar (espacio).${CTR}"
echo -e "${CTA}╚$(printf '═%.0s' $(seq 1 $((W-2))))╝${CTR}"
echo ""
# Formato COMPLETO (ancho >= 58) vs COMPACTO (móvil/teléfono)
if (( W >= 58 )); then
    echo -e "  ${CTG1}✅ [1]${CTR}  SSL/TLS         ${CTD}Ya instalado (Puerto 443)${CTR}"
    echo -e "  ${CTG1}✅ [2]${CTR}  OpenSSH         ${CTD}Ya instalado (Puerto 22)${CTR}"
    echo -e "  ${CTG1}   [3]${CTR}  Dropbear        ${CTD}SSH multi-puerto (90,109,143)${CTR}"
    echo -e "  ${CTG1}   [4]${CTR}  BadVPN UDPGW    ${CTD}VoIP/Gaming UDP (7200,7300)${CTR}"
    echo -e "  ${CTG1}   [5]${CTR}  UDP Custom      ${CTD}Tunnel UDP (Puerto 36712)${CTR}"
    echo -e "  ${CTG1}   [6]${CTR}  V2Ray/Xray      ${CTD}VMess WebSocket (Puerto 10002)${CTR}"
    echo -e "  ${CTG1}   [7]${CTR}  ZiVPN           ${CTD}Protocolo premium UDP (5667)${CTR}"
    echo -e "  ${CTG1}   [8]${CTR}  SlowDNS         ${CTD}DNS Tunnel (5300)${CTR}"
    echo -e "  ${CTG1}   [9]${CTR}  Squid Proxy     ${CTD}Proxy HTTP (Puerto 3128)${CTR}"
    echo -e "  ${CTG1}   [10]${CTR} Webmin          ${CTD}Panel administración (10000)${CTR}"
    echo -e "  ${CTG1}   [13]${CTR} Hysteria        ${CTD}UDP QUIC premium (aleatorio)${CTR}"
    echo -e "  ${CTG1}   [14]${CTR} WireGuard       ${CTD}VPN wg0 UDP (Puerto 51820)${CTR}"
    echo -e "  ${CTG1}   [15]${CTR} DTunnel         ${CTD}DTProto Proxy SSL (4443/8082)${CTR}"
    echo -e "  ${CTG1}   [16]${CTR} SystemDNS       ${CTD}systemd-resolved (Puerto 53)${CTR}"
    echo -e "  ${CTG1}   [17]${CTR} Bot Telegram    ${CTD}Bot de gestión (plan con bot)${CTR}"
    echo -e "  ${CTG1}   [18]${CTR} XHTTP_S         ${CTD}SSH-XHTTP TLS/HTTP2 (443/8080)${CTR}"
    echo -e "  ${CTG1}   [19]${CTR} BHTTP v2        ${CTD}SSH-HTTP/2 Bootstrap (80/8443)${CTR}"
    echo -e "  ${CTG1}   [20]${CTR} BTUN            ${CTD}VPN TCP/UDP (Puerto 7300)${CTR}"
    echo -e "  ${CTG1}   [21]${CTR} Shadowsocks     ${CTD}Proxy SOCKS5 cifrado (8388)${CTR}"
    echo -e "  ${CTG1}   [22]${CTR} Payload         ${CTD}5 servidores HTTP (8082-8085)${CTR}"
    echo -e "  ${CTG1}   [23]${CTR} OpenVPN        ${CTD}VPN UDP autenticado (Puerto 1194)${CTR}"
    echo -e "  ${CTG1}   [24]${CTR} SOCKS5         ${CTD}Proxy SOCKS5 dante (Puerto 1080)${CTR}"
    echo -e "  ${CTG1}   [25]${CTR} HCR Relay      ${CTD}HTTP Core Relay (443 SNI hcr)${CTR}"
    echo -e "  ${CTG1}   [26]${CTR} 3X-UI Panel    ${CTD}XRay VMESS/VLESS/Trojan (54323)${CTR}"
    echo -e "  ${CTG1}   [11]${CTR} Todos           ${CTD}Instalar TODOS los protocolos${CTR}"
    echo -e "  ${CTG1}   [12]${CTR} Ninguno         ${CTD}Solo lo básico (OpenSSH+SSL)${CTR}"
else
    # ── MODO MÓVIL: líneas cortas, sin descripción larga que se corte ──
    echo -e "  ${CTG1}✅ [1]${CTR} SSL/TLS (443)"
    echo -e "  ${CTG1}✅ [2]${CTR} OpenSSH (22)"
    echo -e "  ${CTG1}   [3]${CTR} Dropbear (90/109/143)"
    echo -e "  ${CTG1}   [4]${CTR} BadVPN UDPGW (7200/7300)"
    echo -e "  ${CTG1}   [5]${CTR} UDP Custom (36712)"
    echo -e "  ${CTG1}   [6]${CTR} V2Ray/Xray (10002)"
    echo -e "  ${CTG1}   [7]${CTR} ZiVPN (5667)"
    echo -e "  ${CTG1}   [8]${CTR} SlowDNS (5300)"
    echo -e "  ${CTG1}   [9]${CTR} Squid Proxy (3128)"
    echo -e "  ${CTG1}   [10]${CTR} Webmin (10000)"
    echo -e "  ${CTG1}   [13]${CTR} Hysteria (aleatorio)"
    echo -e "  ${CTG1}   [14]${CTR} WireGuard (51820)"
    echo -e "  ${CTG1}   [15]${CTR} DTunnel (4443/8082)"
    echo -e "  ${CTG1}   [16]${CTR} SystemDNS (53)"
    echo -e "  ${CTG1}   [17]${CTR} Bot Telegram"
    echo -e "  ${CTG1}   [18]${CTR} XHTTP_S (443/8080)"
    echo -e "  ${CTG1}   [19]${CTR} BHTTP v2 (80/8443)"
    echo -e "  ${CTG1}   [20]${CTR} BTUN (7300)"
    echo -e "  ${CTG1}   [21]${CTR} Shadowsocks (8388)"
    echo -e "  ${CTG1}   [22]${CTR} Payload (8082-8085)"
    echo -e "  ${CTG1}   [23]${CTR} OpenVPN (1194)"
    echo -e "  ${CTG1}   [24]${CTR} SOCKS5 (1080)"
    echo -e "  ${CTG1}   [25]${CTR} HCR Relay (443)"
    echo -e "  ${CTG1}   [26]${CTR} 3X-UI Panel (54323)"
    echo -e "  ${CTG1}   [11]${CTR} Todos"
    echo -e "  ${CTG1}   [12]${CTR} Ninguno (solo básico)"
fi
echo ""
echo -e "  ${CTG}Escribe los números separados por espacio:${CTR}"
echo -e "  ${CTG}Ejemplo: 3 4 5 6 → Dropbear+BadVPN+UDP+V2Ray${CTR}"
echo ""
# ── Lectura robusta de selección (FIX v7.1 + v8.2.1 AUTO) ──
# Fuentes, por prioridad:
#   1) Env SELECTION_INPUT (bot/automatización: SELECTION_INPUT="3 5 8" bash install.sh)
#   2) AUTO_INSTALL (key detectada) → instalar TODOS los protocolos
#   3) TTY real (instalación interactiva)
#   4) No-TTY (curl|bash, expect, pipe): leer 1 línea del stdin con timeout, si no → TODO
if [[ -z "${SELECTION_INPUT:-}" ]]; then
    if [[ "$AUTO_INSTALL" == "1" ]]; then
        # v8.2.5: el plan REAL (Firebase) decide los protocolos.
        # SEGURIDAD: el default es RESTRINGIDO — cualquier plan ausente,
        # desconocido o vacío instala SOLO la lista segura (sin 7/13).
        # Solo los planes premium EXPLÍCITOS instalan TODOS (opción 11).
        case "${FB_REAL_PLAN:-standard}" in
            premium|platino|vitalicio|super|diamante|gold|silver|master|prima|pro)
                SELECTION_INPUT="11"
                ;;
            *)
                SELECTION_INPUT="3 4 5 6 8 9 10 14 15 16 17 18 19 20 21 22 23 24 25 26"
                ;;
        esac
    elif [[ -t 0 ]]; then
        read -rp "$(trx '  ➜ Selección: ')" SELECTION_INPUT
    else
        # No-TTY: intentar leer del pipe (instalación automática)
        if IFS= read -r -t 3 SELECTION_PIPE 2>/dev/null; then
            SELECTION_INPUT="${SELECTION_PIPE:-11}"
        else
            # Sin entrada por pipe → instalar TODO (antes caía en 12 = nada → bug)
            SELECTION_INPUT="11"
        fi
    fi
fi
echo ""

# Normalizar entrada: quitar \r (expect/CRLF), comas, guiones y punto y coma → espacios
SELECTION_INPUT="${SELECTION_INPUT//$'\r'/ }"
SELECTION_INPUT="${SELECTION_INPUT//,/ }"
SELECTION_INPUT="${SELECTION_INPUT//;/ }"
SELECTION_INPUT="${SELECTION_INPUT//-/ }"
SELECTION_INPUT="$(echo "$SELECTION_INPUT" | tr -s ' ' | sed 's/^ *//;s/ *$//')"

# Validar que solo contenga números y espacios
if [[ -n "$SELECTION_INPUT" ]] && [[ ! "$SELECTION_INPUT" =~ ^[0-9\ ]+$ ]]; then
    SELECTION_INPUT=""
fi

# Si quedó vacía/inválida (pipe vacío, \r, input malo) → TODO (antes era 12 = nada)
if [[ -z "$SELECTION_INPUT" ]]; then
    SELECTION_INPUT="11"
fi

# Detectar si seleccionó "todos"
SELECTED=""
if echo "$SELECTION_INPUT" | grep -qE '(^| )11( |$)'; then
    SELECTED="1 2 3 4 5 6 7 8 9 10 13 14 15 16 17 18 19 20 21 22 23 24 25 26"
else
    SELECTED="$SELECTION_INPUT"
fi

# Filtrar protocolos ya instalados (1 y 2)
INSTALLED_PROTOCOLS=""
for NUM in $SELECTED; do
    case "$NUM" in
        1) INSTALLED_PROTOCOLS="$INSTALLED_PROTOCOLS SSL/TLS(443)" ;;
        2) INSTALLED_PROTOCOLS="$INSTALLED_PROTOCOLS OpenSSH(22)" ;;
        3) install_dropbear ;;
        4) install_badvpn ;;
        5) install_udpcustom ;;
        6) install_v2ray ;;
        7) install_zipvpn ;;
        8) install_slowdns ;;
        9) install_squid ;;
        10) install_webmin ;;
        13) install_hysteria ;;
        14) install_wireguard ;;
        15) install_dtunnel ;;
        16) install_systemdns ;;
        17) install_bot ;;
        18) install_xhttp ;;
        19) install_bhttp ;;
        20) install_btun ;;
        21) install_shadowsocks ;;
        22) install_payload ;;
        23) install_openvpn ;;
        24) install_socks5 ;;
        25) install_hcr ;;
        26) install_xui ;;
        12) ;;
        *) ;;
    esac
done

# Resumen de instalación
echo ""
echo -e "${CTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CTR}"
echo -e "${CTB}   📋 RESUMEN DE INSTALACIÓN${CTR}"
echo -e "${CTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CTR}"
if [[ -n "$INSTALLED_PROTOCOLS" ]]; then
    echo -e "${CTG1}   ✅ Ya activos:${CTR}$INSTALLED_PROTOCOLS"
fi

# Leer estado actual
source "$CONFIG" 2>/dev/null
[[ "$DROPBEAR" == "ON" ]]   && echo -e "      🟢${WHITE} Dropbear${RESET}"     || echo -e "      🔴${GRAY} Dropbear${RESET}"
[[ "$BADVPN" == "ON" ]]     && echo -e "      🟢${WHITE} BadVPN${RESET}"       || echo -e "      🔴${GRAY} BadVPN${RESET}"
[[ "$UDP_CUSTOM" == "ON" ]] && echo -e "      🟢${WHITE} UDP Custom${RESET}"   || echo -e "      🔴${GRAY} UDP Custom${RESET}"
[[ "$V2RAY" == "ON" ]]      && echo -e "      🟢${WHITE} V2Ray/Xray${RESET}"  || echo -e "      🔴${GRAY} V2Ray/Xray${RESET}"
[[ "$ZIPVPN" == "ON" ]]     && echo -e "      🟢${WHITE} ZiVPN${RESET}"       || echo -e "      🔴${GRAY} ZiVPN${RESET}"
[[ "$SLOWDNS" == "ON" ]]    && echo -e "      🟢${WHITE} SlowDNS${RESET}"     || echo -e "      🔴${GRAY} SlowDNS${RESET}"
[[ "$SQUID" == "ON" ]]      && echo -e "      🟢${WHITE} Squid${RESET}"       || echo -e "      🔴${GRAY} Squid${RESET}"
[[ "$WEBMIN" == "ON" ]]     && echo -e "      🟢${WHITE} Webmin${RESET}"       || echo -e "      🔴${GRAY} Webmin${RESET}"
[[ "$HYSTERIA" == "ON" ]]   && echo -e "      🟢${WHITE} Hysteria${RESET}"     || echo -e "      🔴${GRAY} Hysteria${RESET}"
[[ "$WG" == "ON" ]]         && echo -e "      🟢${WHITE} WireGuard${RESET}"    || echo -e "      🔴${GRAY} WireGuard${RESET}"
[[ "$DTUNNEL" == "ON" ]]    && echo -e "      🟢${WHITE} DTunnel${RESET}"       || echo -e "      🔴${GRAY} DTunnel${RESET}"
[[ "$SYSTEMDNS" == "ON" ]]  && echo -e "      🟢${WHITE} SystemDNS${RESET}"     || echo -e "      🔴${GRAY} SystemDNS${RESET}"
[[ "$OPENVPN" == "ON" ]]    && echo -e "      🟢${WHITE} OpenVPN${RESET}"       || echo -e "      🔴${GRAY} OpenVPN${RESET}"
[[ "$SOCKS5" == "ON" ]]     && echo -e "      🟢${WHITE} SOCKS5${RESET}"        || echo -e "      🔴${GRAY} SOCKS5${RESET}"
[[ "$HCR" == "ON" ]]        && echo -e "      🟢${WHITE} HCR Relay (443)${RESET}" || echo -e "      🔴${GRAY} HCR Relay (443)${RESET}"
if systemctl is-active --quiet x-ui 2>/dev/null; then
    echo -e "      🟢${WHITE} 3X-UI Panel (54323)${RESET}"
else
    echo -e "      🔴${GRAY} 3X-UI Panel (54323)${RESET}"
fi
if systemctl is-active --quiet 'movivip-*-admin' 2>/dev/null; then
    echo -e "      🟢${WHITE} Bot Telegram${RESET}"
else
    echo -e "      🔴${GRAY} Bot Telegram${RESET}"
fi
echo -e "${CTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CTR}"
echo ""

#==============================
# GUARDAR IPTABLES FINALES (todos los puertos de protocolos seleccionados)
#==============================

run_cmd "Guardando reglas iptables finales" "$LINENO" "iptables-save > /etc/iptables/rules.v4"

#==============================
# CONFIGURAR FAIL2BAN (seguridad)
#==============================

step "Configurando Fail2ban..."

run_cmd "Ejecutando fail2ban.sh" "$LINENO" "timeout 120 bash /etc/movivip/herramientas/fail2ban.sh --install"
run_cmd "Habilitando fail2ban" "$LINENO" "timeout 30 systemctl enable fail2ban"
run_cmd "Iniciando fail2ban" "$LINENO" "timeout 30 systemctl restart fail2ban"

#==============================
# CONSUMO DE RED — cron (base de datos vacía)
#==============================

step "Activando monitoreo de consumo de red..."

run_cmd "Ejecutando snapshot inicial" "$LINENO" "mkdir -p /etc/movivip/sistema; chmod +x /etc/movivip/herramientas/network_snapshot.sh; rm -f /etc/movivip/sistema/network_state.conf; bash /etc/movivip/herramientas/network_snapshot.sh"
run_cmd "Configurando cron network_snapshot" "$LINENO" "(crontab -l 2>/dev/null | grep -v 'network_snapshot'; echo '* * * * * bash /etc/movivip/herramientas/network_snapshot.sh >/dev/null 2>&1') | crontab -"

if [[ ! -f /etc/systemd/system/movivip-net-state.service ]]; then
    cat > /etc/systemd/system/movivip-net-state.service << 'EOF'
[Unit]
Description=MoviVIP Network State - consumo de red
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /etc/movivip/herramientas/network_snapshot.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    run_cmd "Habilitando servicio net-state" "$LINENO" "systemctl daemon-reload; systemctl enable movivip-net-state.service"
fi

#==============================
# CONSUMO POR USUARIO — cron (online.sh --quiet)
#==============================

step "Activando monitoreo de consumo por usuario..."

run_cmd "Ejecutando online.sh inicial" "$LINENO" "mkdir -p /etc/movivip/sistema; chmod +x /etc/movivip/usuarios/online.sh; bash /etc/movivip/usuarios/online.sh --quiet"
run_cmd "Creando archivo de límites de conexiones" "$LINENO" "mkdir -p /etc/movivip/sistema; touch /etc/movivip/sistema/limites_conexiones.conf"
run_cmd "Configurando cron online.sh" "$LINENO" "(crontab -l 2>/dev/null | grep -v 'online.sh --quiet'; echo '*/2 * * * * bash /etc/movivip/usuarios/online.sh --quiet >/dev/null 2>&1') | crontab -"

step "Configurando banner SSH..."

cat > /etc/profile.d/MoviVIP-banner.sh << 'BEOF'
#!/bin/bash
#==================================================
# MoviVIP Network - Premium Welcome Banner v2.1
# Diseño profesional - alineación exacta de panel
#==================================================
[[ $- != *i* ]] && return
clear

# ── Datos del sistema ─────────────────────────────
SERVER=$(hostname)
IP_LOCAL=$(hostname -I 2>/dev/null | awk '{print $1}')
DOMAIN="-"
TG_CHANNEL=""
TG_GROUP=""
if [[ -f /etc/movivip/config.conf ]]; then
    source /etc/movivip/config.conf
    DOMAIN="${SERVER_DOMAIN:-"$IP_LOCAL"}"
    TG_CHANNEL="${TG_CHANNEL:-}"
    TG_GROUP="${TG_GROUP:-}"
fi
UPTIME=$(uptime -p 2>/dev/null | sed 's/up //')
FECHA=$(date +"%d-%m-%Y")
HORA=$(date +"%H:%M:%S")
ONLINE=$(who 2>/dev/null | wc -l)

# ── Colores (ANSI 256) ────────────────────────────
C_RESET="\e[0m"
C_CIAN="\e[38;5;45m"
C_CIAN2="\e[38;5;51m"
C_AZUL="\e[38;5;39m"
C_AZUL2="\e[38;5;33m"
C_DORADO="\e[38;5;220m"
C_AMARILLO="\e[38;5;226m"
C_BLANCO="\e[38;5;255m"
C_GRIS="\e[38;5;245m"
C_VERDE="\e[38;5;82m"
C_ROJO="\e[38;5;203m"
C_MORADO="\e[38;5;201m"
C_NARANJA="\e[38;5;208m"
BOLD="\e[1m"

# ── Utilidades ────────────────────────────────────
COLS=$(tput cols 2>/dev/null || echo 80)

# long: ancho visible de un texto (sin ANSI), cuenta emojis como 2 cols
long() {
    local s
    s=$(printf '%b' "$1" | sed -r 's/\x1B\[[0-9;]*[mK]//g')
    local n
    n=$(printf '%s' "$s" | LC_ALL=C.UTF-8 wc -m 2>/dev/null)
    [[ -z "$n" || "$n" -eq 0 ]] && n=${#s}
    local ne
    ne=$(printf '%s' "$s" | LC_ALL=C.UTF-8 grep -oP '[\x{1F000}-\x{1FAFF}\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE0F}]' 2>/dev/null | wc -l)
    [[ -z "$ne" ]] && ne=0
    echo $(( n + ne ))
}
# center: centra texto (soporta códigos ANSI)
center() {
    local text="$1"
    local len
    len=$(long "$text")
    local pad=$(( (COLS - len) / 2 ))
    [[ $pad -lt 0 ]] && pad=0
    printf '%*s' "$pad" ""
    printf '%b\n' "$text"
}
# hr: línea horizontal adaptada al ancho
hr() {
    local char="${1:-═}"
    local line=""
    local i
    for ((i=0; i<COLS; i++)); do line+="$char"; done
    printf '%b\n' "${C_AZUL}${line}${C_RESET}"
}

# ── Panel (ancho fijo, alineación perfecta) ───────
PW=46                      # ancho interior del panel (celdas)
PL=$(( (COLS - PW - 2) / 2 ))   # padding izquierdo
[[ $PL -lt 0 ]] && PL=0

# p_linea <contenido (sin bordes)>
p_linea() {
    local content="$1"
    local len
    len=$(long "$content")
    local fill=$(( PW - len ))
    [[ $fill -lt 0 ]] && fill=0
    printf '%*s' "$PL" ""
    printf '%b' "${C_MORADO}${BOLD}│${C_RESET}${content}"
    printf '%*s' "$fill" ""
    printf '%b\n' "${C_MORADO}${BOLD}│${C_RESET}"
}
# p_marco_sup / p_marco_inf
_repeat() {
    local char="$1" n="$2" out="" i
    for ((i=0; i<n; i++)); do out+="$char"; done
    printf '%s' "$out"
}
p_marco_sup() {
    printf '%*s' "$PL" ""
    printf '%b' "${C_MORADO}${BOLD}┌"
    printf '%b' "${C_MORADO}$(_repeat '─' "$PW")"
    printf '%b\n' "${C_MORADO}${BOLD}┐${C_RESET}"
}
p_marco_inf() {
    printf '%*s' "$PL" ""
    printf '%b' "${C_MORADO}${BOLD}└"
    printf '%b' "${C_MORADO}$(_repeat '─' "$PW")"
    printf '%b\n' "${C_MORADO}${BOLD}┘${C_RESET}"
}
# p_fila <icono(1celda)> <label> <valor>
p_fila() {
    local icon="$1" label="$2" valor="$3"
    local txt
    txt="  ${C_NARANJA}${icon}${C_RESET} ${C_CIAN}${BOLD}${label}${C_RESET}"
    local len_lbl
    len_lbl=$(( 2 + 1 + 1 + ${#label} + 1 ))   # espacios + icono + espacio + label + :
    local len_val=${#valor}
    local dots=$(( PW - len_lbl - len_val ))
    [[ $dots -lt 1 ]] && dots=1
    local gap=""
    local i
    for ((i=0; i<dots; i++)); do gap+=" "; done
    p_linea "${txt}${gap}${C_BLANCO}${valor}${C_RESET}"
}

# ==================================================
#  BANNER PRINCIPAL
# ==================================================
hr "═"
center ""
center "${C_CIAN2}${BOLD}   ███╗   ███╗ ██████╗ ██╗   ██╗██╗██╗   ██╗██╗██████╗ ${C_RESET}"
center "${C_CIAN}${BOLD}   ████╗ ████║██╔═══██╗██║   ██║██║██║   ██║██║██╔══██╗${C_RESET}"
center "${C_CIAN}${BOLD}   ██╔████╔██║██║   ██║██║   ██║██║██║   ██║██║██████╔╝${C_RESET}"
center "${C_AZUL}${BOLD}   ██║╚██╔╝██║██║   ██║╚██╗ ██╔╝██║╚██╗ ██╔╝██║██╔═══╝ ${C_RESET}"
center "${C_AZUL}${BOLD}   ██║ ╚═╝ ██║╚██████╔╝ ╚████╔╝ ██║ ╚████╔╝ ██║██║     ${C_RESET}"
center "${C_AZUL2}${BOLD}   ╚═╝     ╚═╝ ╚═════╝   ╚═══╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ${C_RESET}"
center ""
center "${C_DORADO}${BOLD}  ──  ◆  M O V I V I P   N E T W O R K  ◆  ──  ${C_RESET}"
center "${C_AMARILLO}${BOLD}        🚀  EDICIÓN PREMIUM — 2026  🚀${C_RESET}"
center ""
hr "═"
center ""

# ── Panel de información ──────────────────────────
p_marco_sup
p_linea "${C_BLANCO}${BOLD}          📊  INFORMACIÓN DEL SERVIDOR          ${C_RESET}"
p_marco_inf
p_marco_sup
p_fila "▶" "Servidor"   "${SERVER}"
p_fila "●" "Dominio"    "${DOMAIN}"
p_fila "◈" "IP Pública" "${IP_LOCAL}"
p_fila "⚡" "Uptime"     "${UPTIME}"
p_fila "✪" "Conectados" "${ONLINE}"
p_fila "◆" "Fecha"      "${FECHA}"
p_fila "◉" "Hora"       "${HORA}"
if [[ -n "$TG_CHANNEL" ]]; then
    p_fila "❯" "Canal"  "${TG_CHANNEL}"
fi
if [[ -n "$TG_GROUP" ]]; then
    p_fila "❯" "Grupo"  "${TG_GROUP}"
fi
p_marco_inf
center ""

# ══════ Panel de planes y precios (informativo, estatico en USDT) ══════
p_marco_sup
p_linea "${C_BLANCO}${BOLD}          💰  PLANES Y PRECIOS  💰          ${C_RESET}"
p_marco_inf
p_marco_sup
p_fila "❯" "BRONCE"        "5 USDT   - 1 dispositivo"
p_fila "❯" "PREMIUM"       "15 USDT  - 2 dispositivos"
p_fila "❯" "BETA/VITALICIA" "100 USDT - Ilimitado"
p_marco_inf
center ""

# ── Usuario / acción ──────────────────────────────
if [[ $EUID -ne 0 ]]; then
    center "${C_ROJO}${BOLD}👑 Usuario${C_RESET}   : ${C_BLANCO}$(whoami)${C_RESET}"
    center "${C_ROJO}${BOLD}⚠️  Advertencia${C_RESET} : ${C_AMARILLO}No eres root — ejecuta:${C_RESET} ${C_VERDE}sudo -i${C_RESET}"
else
    center "${C_DORADO}${BOLD}👑 Usuario${C_RESET}   : ${C_BLANCO}root${C_RESET}"
    center "${C_DORADO}${BOLD}⚡ Comando${C_RESET}   : ${C_VERDE}Escribe:${C_RESET} ${C_BLANCO}menu${C_RESET}"
fi
center ""

hr "═"
center ""
center "${C_VERDE}${BOLD}✨  Gracias por usar nuestros servicios  ✨${C_RESET}"
# Sello de marca: SOLO visible para cliente normal. Admin/SuperAdmin pueden quitarlo.
_SELLO_OK=1
if [[ -f /etc/movivip/licencia.conf ]]; then
    source /etc/movivip/licencia.conf
    case "${TIPO:-}" in
        admin|superadmin) _SELLO_OK=0 ;;
    esac
    case "${PLAN:-}" in
        super) _SELLO_OK=0 ;;
    esac
fi
if [[ "$_SELLO_OK" == "1" ]]; then
    center "${C_ROJO}${BOLD}🛡️  SISTEMA PROTEGIDO POR MOVIVIP NETWORK  🛡️${C_RESET}"
else
    center "${C_GRIS}─  Acceso autorizado. Conexiones monitoreadas las 24 horas.  ─${C_RESET}"
fi
center "${C_GRIS}─  Powered by MoviVIP Network — Uso autorizado  ─${C_RESET}"
center ""
hr "═"
printf '\n'
BEOF

# v8.2.16 FIX: /etc/issue.net SIEMPRE es HTML limpio de marca con el sello
# 🛡 SISTEMA PROTEGIDO POR MOVIVIP NETWORK 🛡 DENTRO del HTML (antes de </html>).
# NUNCA se anexa texto plano fuera del HTML (bug que dejaba "◆ SISTEMA..." suelto).
if [[ -f "/etc/movivip/lib/banners/issue_net_3d.html" ]]; then
    cp -f /etc/movivip/lib/banners/issue_net_3d.html /etc/issue.net
else
    cat > /etc/issue.net << 'IEOF'
<html>
<body style='margin:0;padding:0;background:transparent'>
<div style='text-align:center'><span style="font-family:'Comic Sans MS',cursive,sans-serif;font-weight:bold;">
<br><br>
<font color='#FFD700'><big><big>🛡️ 🛡  MOVIVIP NETWORK  🛡 🛡️</big></big></font><br>
<font color='#29b6f6'>════════════════════════════</font><br><br>
<font color='#FFD700'><big><big><big>🐉</big></big></big></font><br>
<font color="#00ffff"><small><i>🛡SISTEMA PROTEGIDO POR MOVIVIP NETWORK🛡</i></small></font>
</span></div>
</body>
</html>
IEOF
fi

run_cmd "Configurando banner en sshd_config" "$LINENO" "grep -q '^Banner' /etc/ssh/sshd_config 2>/dev/null && sed -i 's|^Banner.*|Banner /etc/issue.net|' /etc/ssh/sshd_config || echo 'Banner /etc/issue.net' >> /etc/ssh/sshd_config"
run_cmd "Configurando banner en dropbear" "$LINENO" "grep -q 'DROPBEAR_BANNER' /etc/default/dropbear 2>/dev/null || echo 'DROPBEAR_BANNER=\"/etc/issue.net\"' >> /etc/default/dropbear"
run_cmd "Reiniciando SSH y Dropbear" "$LINENO" "systemctl restart ssh 2>/dev/null; systemctl restart dropbear 2>/dev/null; systemctl restart dropbear_custom 2>/dev/null; true"

# ═══════════════════════════════════════════════════════════════
# BOT GENERADOR DE LICENCIAS — INSTALACIÓN OPCIONAL
# Solo se instala si el script bot-generador.sh existe
# y los secrets encriptados están en /etc/movivip/secrets/
# ═══════════════════════════════════════════════════════════════

if [[ -f "$BASE/herramientas/bot-generador.sh" ]]; then
    step "Configurando Bot Generador de Licencias..."

    # Verificar si existen los secrets encriptados
    if [[ -f "$BASE/secrets/encrypted/config-generador.ps1.enc" ]]; then
        # Crear servicio systemd
        cat > /etc/systemd/system/movivip-bot-generador.service << 'BOTEOF'
[Unit]
Description=MoviVIP Bot Generador de Licencias
After=network.target

[Service]
Type=simple
ExecStart=/etc/movivip/herramientas/bot-generador.sh
Restart=always
RestartSec=10
Environment=MOVIVIP_MASTER_KEY_FILE=/etc/movivip/.master-key
EnvironmentFile=-/etc/movivip/.env-bot

[Install]
WantedBy=multi-user.target
BOTEOF

        chmod +x "$BASE/herramientas/bot-generador.sh"

        # Crear archivo .env-bot si no existe
        if [[ ! -f "$BASE/.env-bot" ]]; then
            # Cargar token del bot desde config si existe
            BOT_TOKEN_VAL="${MOVIVIP_BOT_TOKEN:-}"
            if [[ -n "$BOT_TOKEN_VAL" ]]; then
                echo "MOVIVIP_BOT_TOKEN=$BOT_TOKEN_VAL" > "$BASE/.env-bot"
                chmod 600 "$BASE/.env-bot"
            fi
        fi

        systemctl daemon-reload
        systemctl enable movivip-bot-generador

        echo -e "      ${GREEN}✔${RESET} Bot Generador configurado y habilitado"
        echo -e "      ${GRAY}  → Para iniciar: systemctl start movivip-bot-generador${RESET}"
        echo -e "      ${GRAY}  → Requiere: .master-key + secrets encriptados${RESET}"
    else
        echo -e "      ${GRAY}⚠ Bot Generador: secrets no encontrados — saltando${RESET}"
        echo -e "      ${GRAY}  → Instala manualmente con: /etc/movivip/herramientas/setup-bot-generador.sh${RESET}"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════════════════════════

# FIX v6.5: restaurar usuarios ZipVPN + Xray preservados antes de limpiar
restaurar_usuarios_vpn

step "Instalación completada"

echo ""
if [ "$(tput cols 2>/dev/null || echo 80)" -ge 58 ]; then
    echo -e "${GREEN}   ╔══════════════════════════════════════════════════════════════╗${RESET}"
    show_progress_bar "$INSTALL_TOTAL" "$INSTALL_TOTAL" "100% — INSTALACIÓN COMPLETADA ✅"
    echo ""
    echo -e "${GREEN}   ╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    source "$CONFIG" 2>/dev/null
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║${GOLD}            ✅ INSTALACIÓN COMPLETADA                      ${CYAN}║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${WHITE}  Dominio  : ${GREEN}$SERVER_DOMAIN${RESET}${CYAN}                              ║${RESET}"
    echo -e "${CYAN}║${WHITE}  SSL/TLS  : ${GREEN}$SSL_TUNNEL${RESET}${CYAN}                                  ║${RESET}"
    echo -e "${CYAN}║${WHITE}  CloudFlr : ${GREEN}$CLOUDFLARE_STATUS${RESET}${CYAN}                                  ║${RESET}"
    echo -e "${CYAN}║${WHITE}  Idioma   : ${GREEN}$INSTALL_LANG${RESET}${CYAN}                                  ║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${GOLD}  Protocolos activos:${RESET}${CYAN}                                     ║${RESET}"
    echo -e "${CYAN}║${WHITE}  🚀 OpenSSH    : ${GREEN}${OPENSSH:-OFF}${RESET}${CYAN}                                 ║${RESET}"
    echo -e "${CYAN}║${WHITE}  🔐 SSL/TLS    : ${GREEN}${SSL:-OFF}${RESET}${CYAN}                                 ║${RESET}"
    echo -e "${CYAN}║${WHITE}  🚪 Dropbear   : ${GREEN}${DROPBEAR:-OFF}${RESET}${CYAN}                                ║${RESET}"
    echo -e "${CYAN}║${WHITE}  ⚡ BadVPN     : ${GREEN}${BADVPN:-OFF}${RESET}${CYAN}                                ║${RESET}"
    echo -e "${CYAN}║${WHITE}  📡 UDP Custom : ${GREEN}${UDP_CUSTOM:-OFF}${RESET}${CYAN}                                ║${RESET}"
    echo -e "${CYAN}║${WHITE}  🌐 V2Ray      : ${GREEN}${V2RAY:-OFF}${RESET}${CYAN}                                ║${RESET}"
    echo -e "${CYAN}║${WHITE}  🔒 ZiVPN      : ${GREEN}${ZIPVPN:-OFF}${RESET}${CYAN}                                ║${RESET}"
    echo -e "${CYAN}║${WHITE}  🌍 SlowDNS    : ${GREEN}${SLOWDNS:-OFF}${RESET}${CYAN}                                ║${RESET}"
    echo -e "${CYAN}║${WHITE}  🐟 Squid      : ${GREEN}${SQUID:-OFF}${RESET}${CYAN}                                ║${RESET}"
    echo -e "${CYAN}║${WHITE}  🖥️ Webmin     : ${GREEN}${WEBMIN:-OFF}${RESET}${CYAN}                                ║${RESET}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${RESET}"
    echo -e "${CYAN}║${WHITE}  📦 Paquetes básicos: INSTALADO                          ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE}  🌐 Multi-idioma: 10 idiomas disponibles                 ${CYAN}║${RESET}"
    echo -e "${CYAN}║${WHITE}  💡 Cambia protocolos desde el menú principal            ${CYAN}║${RESET}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
else
    echo ""
    show_progress_bar "$INSTALL_TOTAL" "$INSTALL_TOTAL" "100% — INSTALACIÓN COMPLETADA ✅"
    echo ""
    mv_hr
    echo -e "${GOLD}  ✅ INSTALACIÓN COMPLETADA${RESET}"
    mv_hr
    source "$CONFIG" 2>/dev/null
    echo -e "${WHITE}  Dominio    : ${GREEN}${SERVER_DOMAIN:-—}${RESET}"
    echo -e "${WHITE}  SSL/TLS    : ${GREEN}$SSL_TUNNEL${RESET}"
    echo -e "${WHITE}  Cloudflare : ${GREEN}$CLOUDFLARE_STATUS${RESET}"
    echo -e "${WHITE}  Idioma     : ${GREEN}${INSTALL_LANG:-es}${RESET}"
    mv_hr
    echo -e "${GOLD}  Protocolos activos:${RESET}"
    echo -e "${WHITE}  🚀 OpenSSH    : ${GREEN}${OPENSSH:-OFF}${RESET}"
    echo -e "${WHITE}  🔐 SSL/TLS    : ${GREEN}${SSL:-OFF}${RESET}"
    echo -e "${WHITE}  🚪 Dropbear   : ${GREEN}${DROPBEAR:-OFF}${RESET}"
    echo -e "${WHITE}  ⚡ BadVPN     : ${GREEN}${BADVPN:-OFF}${RESET}"
    echo -e "${WHITE}  📡 UDP Custom : ${GREEN}${UDP_CUSTOM:-OFF}${RESET}"
    echo -e "${WHITE}  🌐 V2Ray      : ${GREEN}${V2RAY:-OFF}${RESET}"
    echo -e "${WHITE}  🔒 ZiVPN      : ${GREEN}${ZIPVPN:-OFF}${RESET}"
    echo -e "${WHITE}  🌍 SlowDNS    : ${GREEN}${SLOWDNS:-OFF}${RESET}"
    echo -e "${WHITE}  🐟 Squid      : ${GREEN}${SQUID:-OFF}${RESET}"
    echo -e "${WHITE}  🖥️ Webmin     : ${GREEN}${WEBMIN:-OFF}${RESET}"
    mv_hr
    echo -e "${WHITE}  📦 Paquetes básicos: INSTALADO${RESET}"
    echo -e "${WHITE}  🌐 Multi-idioma: 10 idiomas disponibles${RESET}"
    echo -e "${WHITE}  💡 Cambia protocolos desde el menú principal${RESET}"
    mv_hr
fi
echo ""
echo -e "${WHITE}  🔑 $(trx 'Contraseña root')${RESET}"
    echo -e "${WHITE}    $(trx 'Para cambiar y guardar la clave root')${RESET}  ${GOLD}$(trx 'Menú → Herramientas → 6 (Contraseña Root)')${RESET}"
echo -e "${WHITE}    $(trx 'Para recuperarla cuando la olvides')${RESET}  ${GOLD}Menú → 6 → 2${RESET}"
echo -e "${GRAY}    🔒 Se guarda cifrada (AES-256) en $BASE/.rootcreds — solo root puede leerla${RESET}"
mv_hr
echo -e "${GRAY}  📋 Log de instalación: $INSTALL_LOG${RESET}"
echo -e "${GRAY}  🔄 El servidor se reiniciará en 10 segundos...${RESET}"

# Asegurar que el comando 'menu' esté disponible globalmente
mkdir -p /usr/local/bin
for _L in menu protocolos herramientas usuarios; do
    if [[ -f "/etc/movivip/launchers/$_L" ]]; then
        cp -f "/etc/movivip/launchers/$_L" "/usr/local/bin/$_L"
        chmod +x "/usr/local/bin/$_L"
    elif [[ -f "/etc/movivip/$_L.sh" ]]; then
        printf '#!/bin/bash\nbash /etc/movivip/%s.sh "$@"\n' "$_L" > "/usr/local/bin/$_L"
        chmod +x "/usr/local/bin/$_L"
    fi
done
# Fallback directo si ninguno de los anteriores funcionó
[[ ! -x /usr/local/bin/menu ]] && printf '#!/bin/bash\nbash /etc/movivip/menu.sh "$@"\n' > /usr/local/bin/menu && chmod +x /usr/local/bin/menu

# Neutralizar auto-update para que no descargue install.sh original de studioanime977
for _U in /etc/movivip/auto-update.sh /etc/movivip/updater.sh /etc/movivip/update.sh; do
    [[ -f "$_U" ]] && ! grep -q "^exit 0" "$_U" && sed -i '2i # Auto-update desactivado — instalación sin licencia\nexit 0' "$_U"
done

sleep 10

reboot
