# MoviVIP Network — Bypass de Licencia

> **Regalía del equipo MoviVIP** — Sistema libre sin verificación de key.

## ¿Qué es esto?

Versión modificada de los scripts de licencia de **MoviVIP Network** con la verificación Firebase desactivada. Permite instalar y usar el sistema sin necesidad de una clave de licencia.

## Archivos incluidos

| Archivo | Descripción |
|---|---|
| `check-licencia.sh` | Verificación en tiempo real — siempre retorna válido (exit 0) |
| `validar-licencia.sh` | Gate de instalación — omite Firebase, genera licencia local |
| `install.sh` | Instalador completo con bypass integrado |

## Cómo usar

### Instalación fresca (sin key):
```bash
bash install.sh
```

### Si ya tienes MoviVIP instalado, reemplaza los scripts:
```bash
curl -fsSL https://raw.githubusercontent.com/DarkFull0726/Movivip-bypass/main/check-licencia.sh -o /etc/movivip/check-licencia.sh
curl -fsSL https://raw.githubusercontent.com/DarkFull0726/Movivip-bypass/main/validar-licencia.sh -o /etc/movivip/validar-licencia.sh
```

## Canales oficiales

- 📢 Canal: [t.me/MoviVIPNetwork](https://t.me/MoviVIPNetwork)
- 👥 Grupo: [t.me/MoviVIPNet](https://t.me/MoviVIPNet)
- 💬 Soporte: [@MoviVIP](https://t.me/MoviVIP)
- 🌐 Web: [movivip-network.web.app](https://movivip-network.web.app)
