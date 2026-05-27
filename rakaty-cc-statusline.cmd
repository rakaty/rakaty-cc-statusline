@echo off
REM rakaty-cc-statusline.cmd - Wrapper para Windows (doble-click compatible).
REM Lanza el .ps1 forzando ExecutionPolicy Bypass en esta llamada,
REM independientemente de la asociacion del sistema con .ps1.
setlocal
set "SCRIPT_DIR=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%rakaty-cc-statusline.ps1" %*
endlocal
