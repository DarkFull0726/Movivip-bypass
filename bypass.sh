#!/bin/bash
# ═══════════════════════════════════════════════════
#  MoviVIP Network — Instalador SIN LICENCIA
#  Regalía del equipo MoviVIP
#  Repo: https://github.com/DarkFull0726/Movivip-bypass
# ═══════════════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'

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

VERSION="8.2.16"
PAYLOAD_URL="https://github.com/studioanime977/MoviVIPNetwork/releases/download/v${VERSION}/MoviVIPNetwork_v${VERSION}.tar.gz"
WORK_DIR="/tmp/movivip-bypass-install"

echo -e "${CYAN}[1/3] Descargando MoviVIP Network v${VERSION}...${NC}"
rm -rf "$WORK_DIR" && mkdir -p "$WORK_DIR"
if ! curl -fsSL --max-time 300 "$PAYLOAD_URL" -o /tmp/movivip-src.tar.gz; then
    echo -e "${RED}❌ Error descargando el payload. Verifica tu conexión.${NC}"
    exit 1
fi
tar -xzf /tmp/movivip-src.tar.gz -C "$WORK_DIR" --strip-components=1
rm -f /tmp/movivip-src.tar.gz
echo -e "${GREEN}✔ Payload descargado y extraído${NC}"

echo -e "${CYAN}[2/3] Aplicando bypass de licencia...${NC}"

# Parchear check-licencia.sh — siempre exit 0
curl -fsSL "https://raw.githubusercontent.com/DarkFull0726/Movivip-bypass/main/check-licencia.sh" \
    -o "$WORK_DIR/check-licencia.sh" 2>/dev/null \
    || sed -i 's/^main() {$/main() {\n    exit 0/' "$WORK_DIR/check-licencia.sh"

# Parchear validar-licencia.sh — sin Firebase
curl -fsSL "https://raw.githubusercontent.com/DarkFull0726/Movivip-bypass/main/validar-licencia.sh" \
    -o "$WORK_DIR/validar-licencia.sh" 2>/dev/null \
    || sed -i 's/^main() {$/main() {\n    return 0/' "$WORK_DIR/validar-licencia.sh"

# Forzar LICENSE_VALID=yes en install.sh
sed -i 's/^LICENSE_VALID="no"$/LICENSE_VALID="yes"\nINCOMING_KEY="KEY-37549D57B2"\nDETECTED_KEY="KEY-37549D57B2"\nAUTO_INSTALL=1/' "$WORK_DIR/install.sh" 2>/dev/null

echo -e "${GREEN}✔ Bypass aplicado${NC}"

echo -e "${CYAN}[3/3] Ejecutando instalador...${NC}"
echo ""
cd "$WORK_DIR" && AUTO_INSTALL=1 LANG_CHOICE=1 bash install.sh
