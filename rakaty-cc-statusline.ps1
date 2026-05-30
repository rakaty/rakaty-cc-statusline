# rakaty-cc-statusline — Launcher unificado para Windows / PowerShell
#
# Uso interactivo:
#   Clic derecho > "Ejecutar con PowerShell"
#   powershell -ExecutionPolicy Bypass -File .\rakaty-cc-statusline.ps1
#
# Uso directo (sin menú):
#   powershell -ExecutionPolicy Bypass -File .\rakaty-cc-statusline.ps1 -Install
#   powershell -ExecutionPolicy Bypass -File .\rakaty-cc-statusline.ps1 -Uninstall
[CmdletBinding()]
param(
    [switch]$Install,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$claudeDir    = Join-Path $env:USERPROFILE '.claude'
$scriptsDir   = Join-Path $claudeDir 'scripts'
$settingsFile = Join-Path $claudeDir 'settings.json'
$targetScript = Join-Path $scriptsDir 'statusline.sh'
$cacheFile    = Join-Path $scriptsDir 'model-contexts.json'

# ---------------------------------------------------------------------------
# Contenido del statusline.sh embebido (here-string literal, sin interpolación).
# Se escribe a ~/.claude/scripts/ al instalar.
# ---------------------------------------------------------------------------
$StatuslineScript = @'
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
'@

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-File-NoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding $false))
}

function Test-BashAvailable {
    return [bool](Get-Command bash -ErrorAction SilentlyContinue)
}

function Invoke-Install {
    Write-Host '==> Instalando rakaty-cc-statusline...'

    if (-not (Test-BashAvailable)) {
        Write-Warning 'No se ha encontrado bash en el PATH.'
        Write-Warning 'El statusLine necesita Git Bash o WSL en runtime para ejecutarse.'
        Write-Warning 'Instala Git for Windows: https://git-scm.com/download/win'
        $answer = Read-Host 'Continuar con la instalación de todos modos? (s/N)'
        if ($answer -notmatch '^[sSyY]') { Write-Host 'Cancelado.'; return }
    }

    $timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupFile = "$settingsFile.bak.$timestamp"

    if (-not (Test-Path $scriptsDir)) {
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    }

    if (Test-Path $settingsFile) {
        Copy-Item $settingsFile $backupFile -Force
        Write-Host "    Backup creado: $backupFile"
    }

    # Escribir el statusline.sh embebido (UTF8 sin BOM y EOL Unix)
    $unixContent = ($StatuslineScript -replace "`r`n", "`n")
    Write-File-NoBom -Path $targetScript -Content $unixContent
    Write-Host "    Script copiado: $targetScript"

    # Merge en settings.json preservando el resto de claves
    $statusLine = [PSCustomObject]@{
        type    = 'command'
        command = 'bash "$HOME/.claude/scripts/statusline.sh"'
    }

    if (Test-Path $settingsFile) {
        $raw = Get-Content $settingsFile -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { $raw = '{}' }
        $settings = $raw | ConvertFrom-Json
    } else {
        $settings = New-Object PSObject
    }

    if ($settings.PSObject.Properties.Name -contains 'statusLine') {
        $settings.statusLine = $statusLine
    } else {
        $settings | Add-Member -NotePropertyName 'statusLine' -NotePropertyValue $statusLine -Force
    }

    $json = $settings | ConvertTo-Json -Depth 100
    Write-File-NoBom -Path $settingsFile -Content $json
    Write-Host '    settings.json actualizado con statusLine'

    Write-Host ''
    Write-Host 'Instalación completada.' -ForegroundColor Green
    Write-Host 'Abre o reinicia Claude Code para ver el nuevo statusLine.'
}

function Invoke-Uninstall {
    Write-Host '==> Desinstalando rakaty-cc-statusline...'

    $timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupFile = "$settingsFile.bak.$timestamp"

    if (Test-Path $settingsFile) {
        Copy-Item $settingsFile $backupFile -Force
        Write-Host "    Backup creado: $backupFile"

        $raw = Get-Content $settingsFile -Raw
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $settings = $raw | ConvertFrom-Json
            if ($settings.PSObject.Properties.Name -contains 'statusLine') {
                $settings.PSObject.Properties.Remove('statusLine')
                $json = $settings | ConvertTo-Json -Depth 100
                Write-File-NoBom -Path $settingsFile -Content $json
                Write-Host '    Clave statusLine eliminada de settings.json'
            }
        }
    }

    foreach ($f in @($targetScript, $cacheFile)) {
        if (Test-Path $f) {
            Remove-Item $f -Force
            Write-Host "    Eliminado: $f"
        }
    }

    if ((Test-Path $scriptsDir) -and -not (Get-ChildItem $scriptsDir -Force)) {
        Remove-Item $scriptsDir -Force
        Write-Host "    Carpeta vacía eliminada: $scriptsDir"
    }

    Write-Host ''
    Write-Host 'Desinstalación completada.' -ForegroundColor Green
    Write-Host 'Reinicia Claude Code para volver al statusLine por defecto.'
}

function Show-Menu {
    Write-Host ''
    Write-Host '== rakaty-cc-statusline ==' -ForegroundColor Cyan
    Write-Host ("Sistema: Windows ({0})" -f $PSVersionTable.PSVersion) -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  1) Instalar'                                          -ForegroundColor Yellow
    Write-Host '  2) Desinstalar (volver al statusLine por defecto)'    -ForegroundColor Yellow
    Write-Host '  E) Salir sin hacer nada'                              -ForegroundColor Yellow
    Write-Host ''
}

# ---------------------------------------------------------------------------
# Entrypoint: argumentos o menú interactivo
# ---------------------------------------------------------------------------
if ($Install)   { Invoke-Install;   return }
if ($Uninstall) { Invoke-Uninstall; return }

$done = $false
while (-not $done) {
    Show-Menu
    $opt = Read-Host 'Elige una opción [1/2/E]'
    switch -Regex ($opt) {
        '^1$'    { Invoke-Install;   $done = $true }
        '^2$'    { Invoke-Uninstall; $done = $true }
        '^[Ee]$' { Write-Host 'Salir.'; $done = $true }
        default  { Write-Host ("Opción no válida: '{0}'" -f $opt) -ForegroundColor Red }
    }
}

# Pausa final para que la ventana no se cierre si se ejecutó con doble-clic.
if ($Host.Name -eq 'ConsoleHost') {
    Write-Host ''
    Write-Host 'Pulsa una tecla para cerrar...' -ForegroundColor DarkGray
    [void][System.Console]::ReadKey($true)
}
