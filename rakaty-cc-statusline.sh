#!/usr/bin/env bash
# rakaty-cc-statusline — Launcher unificado para Linux / macOS / Git Bash
#
# Uso interactivo:
#   bash ./rakaty-cc-statusline.sh
#
# Uso directo (sin menú):
#   bash ./rakaty-cc-statusline.sh --install
#   bash ./rakaty-cc-statusline.sh --uninstall
set -e

CLAUDE_DIR="$HOME/.claude"
SCRIPTS_DIR="$CLAUDE_DIR/scripts"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
TARGET_SCRIPT="$SCRIPTS_DIR/statusline.sh"
CACHE_FILE="$SCRIPTS_DIR/model-contexts.json"

# ---------------------------------------------------------------------------
# Contenido del statusline.sh embebido. Se escribe a ~/.claude/scripts/ al instalar.
# ---------------------------------------------------------------------------
read -r -d '' STATUSLINE_SCRIPT <<'STATUSLINE_EOF' || true
#!/usr/bin/env bash
input=$(cat)

CACHE="$HOME/.claude/scripts/model-contexts.json"
model_id=$(echo "$input" | jq -r '.model.id // empty')
total_from_json=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

if [ -n "$total_from_json" ] && [ "$total_from_json" -gt 0 ] 2>/dev/null && [ -n "$model_id" ]; then
  tmp=$(mktemp)
  if [ -f "$CACHE" ]; then
    jq --arg m "$model_id" --argjson v "$total_from_json" '.[$m] = $v' "$CACHE" > "$tmp" 2>/dev/null && mv "$tmp" "$CACHE"
  else
    jq -n --arg m "$model_id" --argjson v "$total_from_json" '{($m): $v}' > "$CACHE" 2>/dev/null
  fi
fi

resolve_total() {
  [ -n "$total_from_json" ] && [ "$total_from_json" -gt 0 ] 2>/dev/null && { echo "$total_from_json"; return; }
  if [ -f "$CACHE" ] && [ -n "$model_id" ]; then
    from_cache=$(jq -r --arg m "$model_id" '.[$m] // empty' "$CACHE" 2>/dev/null)
    [ -n "$from_cache" ] && { echo "$from_cache"; return; }
  fi
  case "$model_id" in
    *opus*)  echo 1000000 ;;
    *)       echo 200000 ;;
  esac
}
total=$(resolve_total)

pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
in_tok=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
cwd=$(echo "$input" | jq -r '.workspace.project_dir // empty')
[ -z "$cwd" ] && cwd=$(pwd)
if [[ "$cwd" =~ ^/([a-zA-Z])/(.*)$ ]]; then
  drive=$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')
  cwd="${drive}:/${BASH_REMATCH[2]}"
fi
cwd="${cwd//\//\\}"

pct_int=${pct%.*}
[ -z "$pct_int" ] && pct_int=0
[ "$pct_int" -gt 100 ] && pct_int=100

used=$((in_tok + cache_create + cache_read))

filled=$((pct_int * 20 / 100))
[ "$filled" -gt 20 ] && filled=20
empty=$((20 - filled))

ch_full=$'\xe2\x96\x88'   # U+2588 FULL BLOCK
ch_empty=$'\xe2\x96\x91'  # U+2591 LIGHT SHADE
bar=""
i=0; while [ "$i" -lt "$filled" ]; do bar="${bar}${ch_full}";  i=$((i+1)); done
i=0; while [ "$i" -lt "$empty"  ]; do bar="${bar}${ch_empty}"; i=$((i+1)); done

if [ "$pct_int" -lt 50 ]; then
  color=$'\033[32m'
elif [ "$pct_int" -lt 75 ]; then
  color=$'\033[33m'
else
  color=$'\033[31m'
fi
reset=$'\033[0m'

fmt_num() {
  local n=$1 result=""
  while [ ${#n} -gt 3 ]; do
    result=",${n: -3}${result}"
    n=${n:0:${#n}-3}
  done
  printf "%s" "${n}${result}"
}

used_fmt=$(fmt_num "$used")
total_fmt=$(fmt_num "$total")

printf "[rakaty.com][Context] %s%s%s %d%% (%s/%s)\n[ %s ] %s" \
  "$color" "$bar" "$reset" "$pct_int" "$used_fmt" "$total_fmt" "$cwd" "$model_name"
STATUSLINE_EOF

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  C_TITLE=$'\033[1;36m'; C_OPT=$'\033[1;33m'; C_DIM=$'\033[2m'; C_ERR=$'\033[1;31m'; C_OK=$'\033[1;32m'; C_RESET=$'\033[0m'
else
  C_TITLE=""; C_OPT=""; C_DIM=""; C_ERR=""; C_OK=""; C_RESET=""
fi

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "${C_ERR}ERROR: jq no está instalado.${C_RESET}"
    echo "  - macOS:         brew install jq"
    echo "  - Ubuntu/Debian: sudo apt-get install jq"
    echo "  - Fedora:        sudo dnf install jq"
    echo "  - Git Bash:      descargar jq.exe de https://stedolan.github.io/jq/"
    exit 1
  fi
}

action_install() {
  require_jq
  local ts backup
  ts=$(date +%Y%m%d-%H%M%S)
  backup="$CLAUDE_DIR/settings.json.bak.$ts"

  echo "==> Instalando rakaty-cc-statusline..."

  mkdir -p "$SCRIPTS_DIR"

  if [ -f "$SETTINGS_FILE" ]; then
    cp "$SETTINGS_FILE" "$backup"
    echo "    Backup creado: $backup"
  fi

  printf "%s\n" "$STATUSLINE_SCRIPT" > "$TARGET_SCRIPT"
  chmod +x "$TARGET_SCRIPT"
  echo "    Script copiado: $TARGET_SCRIPT"

  local statusline_json='{"type":"command","command":"bash \"$HOME/.claude/scripts/statusline.sh\""}'
  local tmp
  tmp=$(mktemp)
  if [ -f "$SETTINGS_FILE" ]; then
    jq --argjson sl "$statusline_json" '.statusLine = $sl' "$SETTINGS_FILE" > "$tmp"
  else
    jq -n --argjson sl "$statusline_json" '{statusLine: $sl}' > "$tmp"
  fi
  mv "$tmp" "$SETTINGS_FILE"
  echo "    settings.json actualizado con statusLine"

  echo ""
  echo "${C_OK}Instalación completada.${C_RESET}"
  echo "Abre o reinicia Claude Code para ver el nuevo statusLine."
}

action_uninstall() {
  require_jq
  local ts backup
  ts=$(date +%Y%m%d-%H%M%S)
  backup="$CLAUDE_DIR/settings.json.bak.$ts"

  echo "==> Desinstalando rakaty-cc-statusline..."

  if [ -f "$SETTINGS_FILE" ]; then
    cp "$SETTINGS_FILE" "$backup"
    echo "    Backup creado: $backup"

    local tmp
    tmp=$(mktemp)
    jq 'del(.statusLine)' "$SETTINGS_FILE" > "$tmp"
    mv "$tmp" "$SETTINGS_FILE"
    echo "    Clave statusLine eliminada de settings.json"
  fi

  local f
  for f in "$TARGET_SCRIPT" "$CACHE_FILE"; do
    if [ -f "$f" ]; then
      rm -f "$f"
      echo "    Eliminado: $f"
    fi
  done

  if [ -d "$SCRIPTS_DIR" ] && [ -z "$(ls -A "$SCRIPTS_DIR" 2>/dev/null)" ]; then
    rmdir "$SCRIPTS_DIR"
    echo "    Carpeta vacía eliminada: $SCRIPTS_DIR"
  fi

  echo ""
  echo "${C_OK}Desinstalación completada.${C_RESET}"
  echo "Reinicia Claude Code para volver al statusLine por defecto."
}

show_menu() {
  echo ""
  echo "${C_TITLE}== rakaty-cc-statusline ==${C_RESET}"
  echo "${C_DIM}Sistema: $(uname -s)${C_RESET}"
  echo ""
  echo "  ${C_OPT}1${C_RESET}) Instalar"
  echo "  ${C_OPT}2${C_RESET}) Desinstalar (volver al statusLine por defecto)"
  echo "  ${C_OPT}E${C_RESET}) Salir sin hacer nada"
  echo ""
}

# ---------------------------------------------------------------------------
# Entrypoint: argumentos o menú interactivo
# ---------------------------------------------------------------------------
case "${1:-}" in
  --install|-i)   action_install;   exit 0 ;;
  --uninstall|-u) action_uninstall; exit 0 ;;
  --help|-h)
    echo "Uso: $0 [--install|--uninstall]"
    echo "Sin argumentos abre el menú interactivo."
    exit 0
    ;;
esac

while true; do
  show_menu
  read -r -p "Elige una opción [1/2/E]: " opt
  case "$opt" in
    1)   action_install;   break ;;
    2)   action_uninstall; break ;;
    E|e) echo "Salir."; exit 0 ;;
    *)   echo "${C_ERR}Opción no válida: '$opt'${C_RESET}" ;;
  esac
done
