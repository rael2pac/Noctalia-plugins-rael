#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Controller Battery Plugin — Self-Extracting Installer
# ──────────────────────────────────────────────────────────────────────────────
# Usage:
#   bash port.sh
#
# Instala o plugin no Noctalia e adiciona na barra.
# Funciona com PS4 (DualShock 4), PS5 (DualSense), Xbox.
#
# Pré-requisitos:
#   - Linux ≥ 6.8 (hid-playstation)
#   - Noctalia shell instalado
#   - Bluetooth ativo (para nomes)
#   - Xbox: kernel module xpadneo
# ──────────────────────────────────────────────────────────────────────────────

ARCHIVE_DIR=$(mktemp -d)
trap "rm -rf '$ARCHIVE_DIR'" EXIT

RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
pass() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }

echo ""
echo -e "${BOLD}Controller Battery Plugin — Installer${NC}"
echo ""

# ── Prerequisites ──────────────────────────────────────────────────────────────
prereq_ok=true
if [ ! -d "$HOME/.config/noctalia" ]; then
  fail "Noctalia config not found at ~/.config/noctalia"; prereq_ok=false
fi
if ! command -v bluetoothctl &>/dev/null; then
  warn "bluetoothctl not found — nomes amigáveis indisponíveis"
fi
kernel_ver=$(uname -r | cut -d. -f1-2)
if awk "BEGIN {exit !($kernel_ver < 6.8)}"; then
  warn "Kernel $kernel_ver pode ser antigo para hid-playstation (PS4/PS5). Mínimo: 6.8"
fi
$prereq_ok || { echo ""; fail "Pré-requisitos não atendidos."; exit 1; }

# ── Extract embedded archive ─────────────────────────────────────────────────
echo -e "${BOLD}Extraindo arquivos...${NC}"
PAYLOAD=$(sed -n '/^__PAYLOAD_BELOW__$/,$ p' "$0" | tail -n +2)
echo "$PAYLOAD" | base64 -d 2>/dev/null | tar xzf - -C "$ARCHIVE_DIR" || {
  fail "Falha ao extrair archive. O arquivo pode estar corrompido."
  exit 1
}
PLUGIN_SRC="$ARCHIVE_DIR/controller-battery-plugin"
pass "Arquivos extraídos"

# ── Install ───────────────────────────────────────────────────────────────────
PLUGIN_ID="controller-battery"
PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/plugins/$PLUGIN_ID"
PLUGIN_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/plugins.json"
SETTINGS_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/settings.json"

echo ""
echo -e "${BOLD}Instalando plugin...${NC}"
mkdir -p "$PLUGIN_DIR/i18n"
cp "$PLUGIN_SRC/manifest.json" "$PLUGIN_DIR/"
cp "$PLUGIN_SRC/BarWidget.qml" "$PLUGIN_DIR/"
cp "$PLUGIN_SRC/Panel.qml" "$PLUGIN_DIR/"
cp "$PLUGIN_SRC/i18n/"*.json "$PLUGIN_DIR/i18n/" 2>/dev/null || true
pass "Plugin copiado para $PLUGIN_DIR"

# ── Enable plugin ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Habilitando plugin...${NC}"
_json_ok=false
if command -v python3 &>/dev/null; then
  python3 -c "
import json, sys
p = '$PLUGIN_JSON'
try:
    with open(p) as f: d = json.load(f)
except FileNotFoundError:
    d = {'sources': [], 'states': {}, 'version': 2}
d.setdefault('states', {})['$PLUGIN_ID'] = {'enabled': True}
with open(p, 'w') as f: json.dump(d, f, indent=4)
" && pass "Plugin habilitado" && _json_ok=true
elif command -v jq &>/dev/null; then
  if [ -f "$PLUGIN_JSON" ]; then
    jq ".states.\"$PLUGIN_ID\" = {\"enabled\": true}" "$PLUGIN_JSON" > "${PLUGIN_JSON}.tmp" \
      && mv "${PLUGIN_JSON}.tmp" "$PLUGIN_JSON" && pass "Plugin habilitado" && _json_ok=true
  else
    echo '{"sources":[],"states":{"controller-battery":{"enabled":true}},"version":2}' > "$PLUGIN_JSON"
    pass "plugins.json criado com plugin habilitado" && _json_ok=true
  fi
fi
$_json_ok || warn "Edite $PLUGIN_JSON manualmente: adicione \"$PLUGIN_ID\": { \"enabled\": true }"

# ── Add to bar ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Adicionando widget na barra...${NC}"
_settings_ok=false
if command -v python3 &>/dev/null; then
  python3 -c "
import json, sys
p = '$SETTINGS_JSON'
try:
    with open(p) as f: d = json.load(f)
except FileNotFoundError:
    sys.stderr.write('settings.json not found\n'); sys.exit(1)
right = d.get('bar', {}).get('widgets', {}).get('right', [])
ids = [w.get('id') for w in right]
if 'plugin:controller-battery' in ids:
    sys.exit(2)
battery_idx = next((i for i, w in enumerate(right) if w.get('id') == 'Battery'), None)
entry = {'id': 'plugin:controller-battery'}
if battery_idx is not None:
    right.insert(battery_idx + 1, entry)
else:
    right.append(entry)
d['bar']['widgets']['right'] = right
with open(p, 'w') as f: json.dump(d, f, indent=4)
" && pass "Widget adicionado na barra" && _settings_ok=true \
  || (r=$?; [ $r = 2 ] && pass "Widget já estava na barra" && _settings_ok=true)
elif command -v jq &>/dev/null; then
  if [ -f "$SETTINGS_JSON" ]; then
    if jq '.bar.widgets.right[] | select(.id == "plugin:controller-battery")' "$SETTINGS_JSON" &>/dev/null; then
      pass "Widget já estava na barra"; _settings_ok=true
    else
      jq '.bar.widgets.right += [{"id": "plugin:controller-battery"}]' "$SETTINGS_JSON" \
        > "${SETTINGS_JSON}.tmp" && mv "${SETTINGS_JSON}.tmp" "$SETTINGS_JSON" \
        && pass "Widget adicionado na barra" && _settings_ok=true
    fi
  fi
fi
$_settings_ok || warn "Adicione manualmente no settings.json (bar.widgets.right): { \"id\": \"plugin:controller-battery\" }"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}Instalação concluída!${NC}"
echo ""
echo "  Próximos passos:"
echo "    1. Reinicie o Noctalia: killall quickshell (ou relogue)"
echo "    2. Conecte o controle via Bluetooth"
echo "    3. A bateria aparece na barra automaticamente"
echo ""
echo "  Detecta automaticamente: DualShock 4, DualSense, Xbox Wireless Controller"
echo "  Suporta PS3/PS4/PS5 via hid-playstation, Xbox via xpadneo"
echo ""

exit 0
__PAYLOAD_BELOW__
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
UAAA
