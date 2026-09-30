#!/bin/bash
# ═══════════════════════════════════════════════════
#  MoviVIP Network — Instalador SIN LICENCIA
#  Regalía del equipo MoviVIP
#  Repo: https://github.com/DarkFull0726/Movivip-bypass
# ═══════════════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   MoviVIP Network — Instalador Libre     ║"
echo "  ║   Sin key · Sin licencia · Sin bloqueos  ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Ejecuta como root: sudo bash bypass.sh${NC}"
    exit 1
fi

PAYLOAD_URL="https://github.com/DarkFull0726/Movivip-bypass/releases/download/v8.2.17/MoviVIPNetwork-bypass-v8.2.17.tar.gz"
WORK_DIR="/tmp/movivip-bypass-install"

echo -e "${CYAN}[1/2] Descargando MoviVIP Network (bypass)...${NC}"
rm -rf "$WORK_DIR" && mkdir -p "$WORK_DIR"
if ! curl -fsSL --max-time 300 "$PAYLOAD_URL" -o /tmp/movivip-bypass.tar.gz; then
    echo -e "${RED}❌ Error descargando. Verifica tu conexión.${NC}"
    exit 1
fi
tar -xzf /tmp/movivip-bypass.tar.gz -C "$WORK_DIR"
rm -f /tmp/movivip-bypass.tar.gz
echo -e "${GREEN}✔ Descargado y listo (sin licencia)${NC}"

echo -e "${CYAN}[2/2] Instalando...${NC}"
echo ""
cd "$WORK_DIR" && AUTO_INSTALL=1 LANG_CHOICE=1 bash install.sh
