# rakaty-cc-statusline

> **Sobre Rakaty.** [Rakaty](https://rakaty.com) es una agencia de **IA y automatización** que ayuda a PYMEs y startups a escalar sin contratar más gente, eliminando tareas manuales mediante automatización de procesos e integración de IA. Sus servicios cubren consultoría/diagnóstico de procesos, automatización con IA sobre herramientas existentes (CRM, ERP, email) y desarrollo de SaaS personalizados. *"Donde la automatización se convierte en crecimiento."*
>
> Esta utilidad nace de ese mismo espíritu: pequeñas piezas que automatizan lo repetitivo para que puedas pensar en otra cosa.

---

StatusLine personalizado para **Claude Code** en una sola pieza: **un launcher por SO**, con menú interactivo para instalar o desinstalar.

Reemplaza la línea de estado por defecto de Claude Code por una vista de dos filas con:

- **Fila 1**: Barra de progreso del contexto con colores (verde <50%, amarillo 50–75%, rojo ≥75%), porcentaje usado y tokens consumidos/totales.
- **Fila 2**: `[ <ruta de trabajo> ] <nombre del modelo>`.

Ejemplo:

```
[rakaty.com][Context] ██░░░░░░░░░░░░░░░░░░ 12% (121,693/1,000,000)
[ C:\Users\Papá ] Opus 4.7
```

El tamaño total de la ventana de contexto se detecta **automáticamente**:

1. Si Claude Code lo pasa por JSON (`context_window.context_window_size`), se usa ese valor y se cachea.
2. Si no, se recupera del caché `~/.claude/scripts/model-contexts.json`.
3. Como último recurso, una tabla mínima por familia de modelo (`opus` → 1M, resto → 200K).

Cuando aparezcan modelos nuevos con ventanas distintas, el script aprenderá el valor en la primera sesión sin necesidad de editar nada.

---

## Requisitos

| Plataforma | Runtime obligatorio |
|------------|---------------------|
| Linux      | `bash` + `jq`       |
| macOS      | `bash` + `jq`       |
| Windows    | **Git Bash** (o WSL) + `jq` en runtime; PowerShell 5.1+ para el launcher |

> En Windows, Claude Code lanza el comando del statusLine mediante `bash`. Por eso necesitas **Git for Windows**: <https://git-scm.com/download/win>. `jq` suele venir con Git Bash; si no, descárgalo de <https://stedolan.github.io/jq/>.

---

## Uso

El paquete contiene **dos launchers + un wrapper de Windows**. Cada launcher trae el statusLine embebido y la lógica de instalar/desinstalar dentro:

### Linux / macOS / Git Bash

```bash
cd claude-code-statusline
bash ./rakaty-cc-statusline.sh
```

### Windows

Tienes **tres formas**, ordenadas de más cómoda a menos:

1. **Doble-click sobre `rakaty-cc-statusline.cmd`** (recomendado).
   El `.cmd` es un wrapper de 1 línea que invoca al `.ps1` con `-ExecutionPolicy Bypass`. Funciona aunque tengas `.ps1` asociado a un editor (Notepad, Notepad++, VSCode…).
2. **Clic derecho sobre `rakaty-cc-statusline.ps1`** > **"Ejecutar con PowerShell"**.
3. **Desde una terminal PowerShell**:
   ```powershell
   cd claude-code-statusline
   .\rakaty-cc-statusline.ps1
   # Si tu ExecutionPolicy lo bloquea:
   powershell -ExecutionPolicy Bypass -File .\rakaty-cc-statusline.ps1
   ```

> ⚠️ **Si haces doble-click directamente sobre el `.ps1` y se te abre Notepad++ (o cualquier otro editor) en lugar de ejecutarse**, es porque Windows tiene asociada la extensión `.ps1` a ese editor. Esto es lo habitual. **Usa el `.cmd`** (opción 1) y olvídate del problema.

---

## El menú

Cualquiera de los tres lanzamientos muestra el mismo menú:

```
== rakaty-cc-statusline ==
Sistema: ...

  1) Instalar
  2) Desinstalar (volver al statusLine por defecto)
  E) Salir sin hacer nada
```

### Opción 1: Instalar

1. Crea (si no existe) la carpeta `~/.claude/scripts/`.
2. Hace **backup** del `~/.claude/settings.json` actual (`settings.json.bak.YYYYMMDD-HHMMSS`).
3. Escribe `statusline.sh` (embebido en el launcher) en `~/.claude/scripts/statusline.sh`.
4. Añade o actualiza la clave `statusLine` en `settings.json` **preservando el resto de claves**.

Tras la instalación, abre/reinicia Claude Code para ver el nuevo statusLine.

### Opción 2: Desinstalar

1. Hace **backup** del `settings.json` actual.
2. Elimina la clave `statusLine` (Claude Code vuelve a su statusLine por defecto).
3. Borra `~/.claude/scripts/statusline.sh` y la caché `model-contexts.json`.
4. Elimina la carpeta `scripts/` si queda vacía.

### Opción E: Salir

No toca nada del sistema.

---

## Modo no interactivo (sin menú)

Si prefieres ejecutar las acciones directamente sin pasar por el menú:

| Acción       | Linux / macOS / Git Bash                          | Windows                                                                              |
|--------------|---------------------------------------------------|--------------------------------------------------------------------------------------|
| Instalar     | `bash ./rakaty-cc-statusline.sh --install`        | `rakaty-cc-statusline.cmd -Install` &nbsp;o&nbsp; `powershell -ExecutionPolicy Bypass -File .\rakaty-cc-statusline.ps1 -Install`   |
| Desinstalar  | `bash ./rakaty-cc-statusline.sh --uninstall`      | `rakaty-cc-statusline.cmd -Uninstall` &nbsp;o&nbsp; `powershell -ExecutionPolicy Bypass -File .\rakaty-cc-statusline.ps1 -Uninstall` |
| Ayuda        | `bash ./rakaty-cc-statusline.sh --help`           | `Get-Help .\rakaty-cc-statusline.ps1`                                                |

---

## Archivos del paquete

| Archivo                       | Plataforma                  | Propósito                                                                |
|-------------------------------|-----------------------------|--------------------------------------------------------------------------|
| `rakaty-cc-statusline.sh`     | Linux / macOS / Git Bash    | Launcher con menú + lógica de instalación + statusLine embebido (LF, UTF-8 sin BOM). |
| `rakaty-cc-statusline.ps1`    | Windows PowerShell          | Equivalente de Windows (CRLF, **UTF-8 con BOM**: imprescindible para PowerShell 5.1). |
| `rakaty-cc-statusline.cmd`    | Windows (doble-click)       | Wrapper que invoca al `.ps1` con `-ExecutionPolicy Bypass`. Resuelve el problema de la asociación `.ps1` → editor. |
| `.gitattributes`              | Git                         | Fuerza line endings y encoding correctos en cada clone/pull, independientemente del SO o `core.autocrlf`. |
| `.editorconfig`               | Editores                    | Asegura que cualquier editor (VSCode, Sublime, etc.) preserve el formato al guardar. |
| `README.md`                   | —                           | Este archivo.                                                            |

> **Por qué `.gitattributes`**: sin él, Git puede convertir CRLF↔LF según la configuración del usuario que clona. Eso rompería el `.sh` en Linux/Mac (error `bad interpreter: /usr/bin/env\r`) y el `.ps1` se quedaría sin BOM tras editarse en algunos entornos. Las reglas declaradas garantizan que cada archivo llega siempre en el formato esperado por su intérprete.

---

## Resolución de problemas

- **No aparece el statusLine nuevo**: cierra y vuelve a abrir Claude Code; los cambios en `settings.json` se cargan al iniciar.
- **En Windows el `.ps1` se abre en un editor (Notepad++, VSCode, etc.) en lugar de ejecutarse**: usa **`rakaty-cc-statusline.cmd`** con doble-click. Es el patrón estándar de la industria (igual que `gradlew`/`gradlew.bat`, `mvnw`/`mvnw.cmd`).
- **Aparece vacío o con errores**: ejecuta manualmente para depurar:
  ```bash
  echo '{"model":{"id":"claude-sonnet-4-6","display_name":"Sonnet 4.6"},"context_window":{"used_percentage":25,"context_window_size":200000,"current_usage":{"input_tokens":50000}},"workspace":{"project_dir":"'"$PWD"'"}}' | bash ~/.claude/scripts/statusline.sh
  ```
- **Quiero restaurar mi `settings.json` original**: en `~/.claude/` encontrarás los backups `settings.json.bak.YYYYMMDD-HHMMSS`. Cópialo encima de `settings.json` para revertir.
- **Edité el `statusline.sh` instalado y quiero conservar mis cambios**: ten en cuenta que la próxima vez que ejecutes Instalar, sobreescribirá `~/.claude/scripts/statusline.sh` con la versión embebida en el launcher.

---

<p align="center">
  Hecho con ☕ por <a href="https://rakaty.com">Rakaty</a> — <em>Donde la automatización se convierte en crecimiento</em>.
</p>
