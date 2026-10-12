#!/bin/bash
# Installation du serveur MCP Odoo (mcp-server-odoo) pour Claude Desktop sur ChromeOS
# A executer dans la console Linux du Chromebook (celle qui donne acces a l'appli Claude).
#
# Hypothese : l'appli "Claude for ChromeOS" est packagee comme Claude Desktop Linux (Electron/Debian),
# donc meme convention de config que Linux : ~/.config/Claude/claude_desktop_config.json.
# Si ce chemin n'existe pas, le script demande le chemin exact (visible dans l'appli via
# Parametres > Developpeur > Modifier la configuration, si ce menu existe sur cette version).
set -euo pipefail

echo "=== Installation MCP Server Odoo (ChromeOS) ==="
echo ""

# 1. Verifier/installer uv (fournit uvx)
if ! command -v uvx &>/dev/null; then
    echo "uvx non trouve, installation de uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi
UVX_PATH=$(command -v uvx)
echo "uvx trouve : $UVX_PATH"
echo ""

# 2. Localiser la config Claude Desktop
CANDIDATES=(
    "$HOME/.config/Claude/claude_desktop_config.json"
)

CONFIG_PATH=""
for candidate in "${CANDIDATES[@]}"; do
    if [ -d "$(dirname "$candidate")" ]; then
        CONFIG_PATH="$candidate"
        break
    fi
done

if [ -z "$CONFIG_PATH" ]; then
    echo "Config Claude Desktop non detectee automatiquement (essaye : ${CANDIDATES[*]})."
    echo "Dans l'appli Claude : Parametres > Developpeur > Modifier la configuration, pour voir le chemin exact."
    read -rp "Chemin vers claude_desktop_config.json (vide pour annuler) : " CONFIG_PATH </dev/tty
    if [ -z "$CONFIG_PATH" ]; then
        echo "Installation annulee : impossible de localiser la config Claude Desktop."
        exit 1
    fi
fi
echo "Config Claude Desktop : $CONFIG_PATH"
echo ""

# 3. Demander les identifiants Odoo
echo "Pour info :"
echo "  - URL Odoo : l'adresse de votre instance (ex: https://nalios.odoo.com)"
echo "  - Base de donnees : visible dans le selecteur de base au login, ou dans l'URL"
echo "  - Email / utilisateur : votre identifiant de connexion Odoo"
echo "  - Cle API : Odoo > votre profil (en haut a droite) > Compte > Securite du compte > Nouvelle cle API"
echo ""
read -rp "Nom du serveur MCP (ex: odoo) [odoo] : " MCP_NAME </dev/tty
MCP_NAME="${MCP_NAME:-odoo}"
read -rp "URL Odoo (ex: https://nalios.odoo.com) : " ODOO_URL </dev/tty
read -rp "Nom de la base de donnees : " ODOO_DB </dev/tty
read -rp "Email / utilisateur Odoo : " ODOO_USER </dev/tty
read -rsp "Cle API Odoo : " ODOO_API_KEY </dev/tty
echo ""
echo ""

# 4. Mettre a jour la config Claude Desktop
mkdir -p "$(dirname "$CONFIG_PATH")"
if [ ! -f "$CONFIG_PATH" ]; then
    echo "{}" > "$CONFIG_PATH"
fi

python3 - "$CONFIG_PATH" "$UVX_PATH" "$ODOO_URL" "$ODOO_DB" "$ODOO_USER" "$ODOO_API_KEY" "$MCP_NAME" <<'EOF'
import json, sys

config_path, uvx_path, url, db, user, api_key, mcp_name = sys.argv[1:8]

with open(config_path) as f:
    config = json.load(f)

config.setdefault("mcpServers", {})

config["mcpServers"][mcp_name] = {
    "command": uvx_path,
    "args": ["mcp-server-odoo@0.9.0"],
    "env": {
        "ODOO_URL": url,
        "ODOO_DB": db,
        "ODOO_USER": user,
        "ODOO_API_KEY": api_key,
        "ODOO_YOLO": "true",
        "ODOO_MCP_DEFAULT_LIMIT": "100",
        "ODOO_MCP_MAX_LIMIT": "1000",
    },
}

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

print(f"Config mise a jour : {config_path}")
EOF

echo ""
echo "=== Termine ==="
echo "Redemarre l'appli Claude pour activer le serveur MCP '$MCP_NAME'."
