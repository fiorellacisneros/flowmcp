#!/usr/bin/env bash
# Minimal i18n: detects/stores a human's language preference once, on their
# first interactive run. Never touches JSON output — agents always get
# English with fixed keys (see schema.sh). This only affects the
# human-readable text a person actually reads (banner, --help, and the
# plain-language guidance printed by add/connect/secret-set/rotate/list).

WFW_LANG_FILE="$WFW_HOME/lang"

# wfw_lang — resolves the active language: WFW_LANG env override, then the
# saved preference file, then "en". Never prompts — safe to call anywhere,
# including from a non-interactive/agent context.
wfw_lang() {
  if [[ -n "${WFW_LANG:-}" ]]; then
    echo "$WFW_LANG"
    return
  fi
  if [[ -f "$WFW_LANG_FILE" ]]; then
    cat "$WFW_LANG_FILE"
    return
  fi
  echo "en"
}

# wfw_prompt_lang_if_needed — asks once, only for a real interactive human
# (both stdin and stdout are TTYs), with no saved preference and no WFW_LANG
# override already set. Never runs for an agent's non-interactive Bash call
# — same rule as secret-set/rotate: no command may block a non-interactive
# run.
wfw_prompt_lang_if_needed() {
  [[ -n "${WFW_LANG:-}" ]] && return 0
  [[ -f "$WFW_LANG_FILE" ]] && return 0
  [[ -t 0 && -t 1 ]] || return 0

  echo "Choose a language / Elige un idioma:"
  echo "  [1] English"
  echo "  [2] Español"
  local choice
  read -r -p "> " choice
  case "$choice" in
    2|es|Es|ES) echo "es" > "$WFW_LANG_FILE" ;;
    *)          echo "en" > "$WFW_LANG_FILE" ;;
  esac
}

# wfw_t <key> [args...] — looks up a human-facing message in the active
# language and printf-substitutes any extra args into it (%s placeholders).
# English is the fallback for any key not yet translated in Spanish, and for
# any unknown key entirely (returns the key itself, so a typo is visible,
# not silent).
wfw_t() {
  local key="$1"; shift || true
  local msg
  if [[ "$(wfw_lang)" == "es" ]]; then
    msg="$(wfw_t_es "$key")"
  else
    msg="$(wfw_t_en "$key")"
  fi
  if [[ $# -gt 0 ]]; then
    printf -- "$msg\n" "$@"
  else
    printf '%s\n' "$msg"
  fi
}

wfw_t_es() {
  local key="$1"
  case "$key" in
    tagline)              echo "conecta Webflow a tu agente de IA, sin exponer tus tokens" ;;
    usage)                echo "USO" ;;
    onboarding)           echo "PRIMEROS PASOS" ;;
    daily_use)            echo "USO DIARIO" ;;
    security_1)           echo "seguridad · esta herramienta nunca acepta un token como argumento y" ;;
    security_2)           echo "nunca lo imprime. secret-set/rotate requieren una terminal interactiva real;" ;;
    security_3)           echo "connect abre un navegador real (via mcp-remote, OAuth propio de Webflow — sin apps que configurar)." ;;
    cmd_connect)          echo "<org> [--label NOMBRE] — agrega un cliente por navegador, sin configuración (recomendado)" ;;
    cmd_add)              echo "<org> [--label NOMBRE] — registra solo los metadatos del org" ;;
    cmd_secret_set)       echo "<org> — pega un token manualmente (alternativa sin navegador)" ;;
    cmd_rotate)           echo "<org> — reemplaza un token guardado" ;;
    cmd_list)             echo "lista los orgs registrados + último estado de test" ;;
    cmd_inspect)          echo "<org> [--live] — muestra el detalle del perfil" ;;
    cmd_test)             echo "<org> — valida las credenciales guardadas" ;;
    cmd_install)          echo "<org> <client> [--scope user|project] [--force]" ;;
    cmd_install_clients)  echo "client: claude-code | claude-desktop | cursor" ;;
    cmd_remove)           echo "<org> --yes [--from client:scope]... — elimina perfil + credenciales" ;;
    cmd_debug)            echo "<org> — diagnostica una conexión rota" ;;
    cmd_rename)           echo "<old-org> <new-org> — sin necesidad de volver a autenticar" ;;
    cmd_schema)           echo "referencia de comandos/JSON legible por máquina, para agentes" ;;
    cmd_lang)             echo "[en|es] — ver o cambiar el idioma de la salida para humanos" ;;
    msg_no_orgs)          echo "Todavía no hay orgs registrados. Corre 'flowmcp add <org>' para empezar." ;;
    msg_reconnecting)     echo "reconectando org existente '%s'..." ;;
    msg_connect_opening)  echo "Abriendo tu navegador para que '%s' apruebe el acceso a Webflow..." ;;
    msg_connect_ctrlc1)   echo "En cuanto lo veas conectado abajo, presiona Ctrl+C para volver aquí — tu" ;;
    msg_connect_ctrlc2)   echo "sesión ya queda guardada en disco en ese momento." ;;
    msg_add_recommend)    echo "primero intenta 'flowmcp connect %s' — inicia sesión por navegador, sin copiar/pegar ningún token" ;;
    msg_add_no_browser)   echo "¿Sin navegador disponible? Corre esto tú mismo, en tu propia terminal (no a través de un agente):" ;;
    msg_add_run_yourself) echo "corre esto tú mismo, en tu propia terminal (no a través de un agente):" ;;
    msg_add_explain1)     echo "Te va a pedir el token de la API de Webflow con entrada oculta y lo guardará" ;;
    msg_add_explain2)     echo "directamente en %s. El token nunca se pasa como argumento de comando" ;;
    msg_add_explain3)     echo "ni se imprime." ;;
    msg_need_tty_secret)  echo "error: secret-set requiere una terminal interactiva (stdin no es una TTY)." ;;
    msg_need_tty_rotate)  echo "error: rotate requiere una terminal interactiva (stdin no es una TTY)." ;;
    msg_run_yourself1)    echo "Corre este comando tú mismo, en una ventana de terminal real — no le hagas" ;;
    msg_run_yourself2)    echo "pipe de entrada ni lo corras vía un agente/herramienta de automatización." ;;
    msg_run_yourself_short) echo "Corre este comando tú mismo, en una ventana de terminal real." ;;
    msg_secretset_enter)  echo "Ingresa el token de la API de Webflow para '%s' (entrada oculta, presiona Enter al terminar):" ;;
    msg_secretset_stored) echo "Token guardado para '%s' vía %s." ;;
    msg_rotate_enter)     echo "Rotando el token de '%s'. Ingresa el nuevo token de la API de Webflow (entrada oculta):" ;;
    msg_rotate_done)      echo "Token rotado para '%s' vía %s." ;;
    msg_test_hint)        echo "Corre 'flowmcp test %s' para verificar que funciona." ;;
    msg_test_hint_new)    echo "Corre 'flowmcp test %s' para verificar que el nuevo token funciona." ;;
    msg_inspect_no_session) echo "nota: aún no hay sesión guardada para '%s' — corre 'flowmcp connect %s'" ;;
    msg_inspect_no_token) echo "nota: aún no hay token guardado para '%s' — corre 'flowmcp secret-set %s'" ;;
    msg_invalid_org)      echo "el nombre del org debe ser alfanumérico en minúsculas con - o _ (recibido '%s')" ;;
    msg_org_not_found)    echo "no existe el org '%s'" ;;
    msg_org_exists)       echo "el org '%s' ya existe (usa 'rotate' para cambiar su token, o 'remove' primero)" ;;
    msg_add_ok)           echo "org '%s' registrado (label: %s) · backend de secretos: %s" ;;
    msg_lang_set)         echo "idioma cambiado a %s" ;;
    msg_connect_success)  echo "'%s' conectado vía OAuth de Webflow" ;;
    msg_connect_next)     echo "flowmcp test %s — o 'install %s <client>' para conectarlo" ;;
    msg_connect_fail)     echo "no se encontró una sesión completa para '%s' — puede que el login no haya terminado" ;;
    msg_connect_fail_hint) echo "corre 'flowmcp connect %s' de nuevo y espera a que muestre conectado" ;;
    msg_remove_confirm_needed) echo "esto elimina el perfil y el token guardado de '%s'." ;;
    msg_remove_confirm_hint)   echo "vuelve a correrlo con --yes para confirmar" ;;
    msg_remove_stripped)  echo "se quitó 'webflow-%s' de %s" ;;
    msg_remove_ok)        echo "org '%s' eliminado (perfil + credenciales guardadas)" ;;
    msg_install_no_org)   echo "no existe el org '%s' — corre 'flowmcp add %s' o 'connect %s' primero" ;;
    msg_install_ok)       echo "'%s' instalado en %s" ;;
    msg_install_note_mcpremote) echo "esta entrada corre mcp-remote contra el servidor MCP hosteado de Webflow — no hay ningún token en este archivo, mcp-remote lee su propia sesión aislada" ;;
    msg_install_note_pat) echo "esta entrada hace referencia a run-mcp.sh, no a un token literal" ;;
    msg_install_restart)  echo "reinicia %s para que lo tome" ;;
    msg_rename_new_exists) echo "el org '%s' ya existe — elimínalo primero o elige otro nombre" ;;
    msg_rename_ok)        echo "'%s' renombrado a '%s' — no hace falta volver a iniciar sesión" ;;
    msg_rename_hint)      echo "reinicia cualquier cliente cuyo config se haya actualizado para que tome el nuevo nombre" ;;
    msg_test_mcpremote_ok) echo "'%s' tiene una sesión de Webflow guardada (mcp-remote)" ;;
    msg_test_note1)       echo "nota: esto solo confirma que hay una sesión guardada en tu computadora —" ;;
    msg_test_note2)       echo "no la prueba contra Webflow todavía. Eso pasa solo, cuando abras Claude Code," ;;
    msg_test_note3)       echo "Claude Desktop o Cursor: si venció, la renuevan o te piden iniciar sesión de nuevo." ;;
    msg_test_pat_ok)      echo "el token de '%s' es válido · sitios accesibles: %s" ;;
    msg_test_scopes)      echo "permisos: %s" ;;
    msg_test_next_intro)  echo "instálalo en el cliente que uses:" ;;
    *)                    wfw_t_en "$key" ;;
  esac
}

wfw_t_en() {
  local key="$1"
  case "$key" in
    tagline)              echo "connects Webflow to your AI agent, without exposing your tokens" ;;
    usage)                echo "USAGE" ;;
    onboarding)           echo "ONBOARDING" ;;
    daily_use)            echo "DAILY USE" ;;
    security_1)           echo "security · this tool never accepts a token as a command-line argument and" ;;
    security_2)           echo "never prints one. secret-set/rotate require a real interactive TTY;" ;;
    security_3)           echo "connect opens a real browser (via mcp-remote, Webflow's own OAuth — no app to set up)." ;;
    cmd_connect)          echo "<org> [--label NAME] — add a client via browser, no setup needed (recommended)" ;;
    cmd_add)              echo "<org> [--label NAME] — register org metadata only" ;;
    cmd_secret_set)       echo "<org> — paste a token manually (headless fallback)" ;;
    cmd_rotate)           echo "<org> — replace a stored token" ;;
    cmd_list)             echo "list registered orgs + last test status" ;;
    cmd_inspect)          echo "<org> [--live] — show profile detail" ;;
    cmd_test)             echo "<org> — validate the stored credentials" ;;
    cmd_install)          echo "<org> <client> [--scope user|project] [--force]" ;;
    cmd_install_clients)  echo "client: claude-code | claude-desktop | cursor" ;;
    cmd_remove)           echo "<org> --yes [--from client:scope]... — delete profile + credentials" ;;
    cmd_debug)            echo "<org> — diagnose a broken connection" ;;
    cmd_rename)           echo "<old-org> <new-org> — no re-login needed" ;;
    cmd_schema)           echo "machine-readable command/JSON reference for agents" ;;
    cmd_lang)             echo "[en|es] — view or change the human-readable output language" ;;
    msg_no_orgs)          echo "No orgs registered yet. Run 'flowmcp add <org>' to start." ;;
    msg_reconnecting)     echo "reconnecting existing org '%s'..." ;;
    msg_connect_opening)  echo "Opening your browser for '%s' to approve access to Webflow..." ;;
    msg_connect_ctrlc1)   echo "Once you see it connect below, press Ctrl+C to return here — your" ;;
    msg_connect_ctrlc2)   echo "session is already saved to disk by that point." ;;
    msg_add_recommend)    echo "try 'flowmcp connect %s' first — browser login, no token to copy/paste" ;;
    msg_add_no_browser)   echo "No browser available? Run this yourself, in your own terminal (not through an agent):" ;;
    msg_add_run_yourself) echo "run this yourself, in your own terminal (not through an agent):" ;;
    msg_add_explain1)     echo "It will prompt for the Webflow API token with hidden input and store it" ;;
    msg_add_explain2)     echo "directly in %s. The token is never passed as a command argument" ;;
    msg_add_explain3)     echo "and never printed." ;;
    msg_need_tty_secret)  echo "error: secret-set requires an interactive terminal (stdin is not a TTY)." ;;
    msg_need_tty_rotate)  echo "error: rotate requires an interactive terminal (stdin is not a TTY)." ;;
    msg_run_yourself1)    echo "Run this command yourself in a real terminal window — do not pipe input" ;;
    msg_run_yourself2)    echo "into it and do not run it via an agent/automation tool." ;;
    msg_run_yourself_short) echo "Run this command yourself in a real terminal window." ;;
    msg_secretset_enter)  echo "Enter Webflow API token for '%s' (input hidden, press Enter when done):" ;;
    msg_secretset_stored) echo "Stored token for '%s' via %s." ;;
    msg_rotate_enter)     echo "Rotating token for '%s'. Enter the new Webflow API token (input hidden):" ;;
    msg_rotate_done)      echo "Rotated token for '%s' via %s." ;;
    msg_test_hint)        echo "Run 'flowmcp test %s' to verify it works." ;;
    msg_test_hint_new)    echo "Run 'flowmcp test %s' to verify the new token works." ;;
    msg_inspect_no_session) echo "note: no saved session yet for '%s' — run 'flowmcp connect %s'" ;;
    msg_inspect_no_token) echo "note: no token stored yet for '%s' — run 'flowmcp secret-set %s'" ;;
    msg_invalid_org)      echo "org name must be lowercase alphanumeric with - or _ (got '%s')" ;;
    msg_org_not_found)    echo "no org '%s' registered" ;;
    msg_org_exists)       echo "org '%s' already exists (use 'rotate' to change its token, or 'remove' first)" ;;
    msg_add_ok)           echo "registered org '%s' (label: %s) · secret backend: %s" ;;
    msg_lang_set)         echo "language set to %s" ;;
    msg_connect_success)  echo "connected '%s' via Webflow's OAuth" ;;
    msg_connect_next)     echo "flowmcp test %s — or 'install %s <client>' to wire it up" ;;
    msg_connect_fail)     echo "no completed session found for '%s' — the login may not have finished" ;;
    msg_connect_fail_hint) echo "run 'flowmcp connect %s' again and wait until it shows connected" ;;
    msg_remove_confirm_needed) echo "this deletes the profile and the stored token for '%s'." ;;
    msg_remove_confirm_hint)   echo "re-run with --yes to confirm" ;;
    msg_remove_stripped)  echo "removed 'webflow-%s' from %s" ;;
    msg_remove_ok)        echo "removed org '%s' (profile + stored credentials)" ;;
    msg_install_no_org)   echo "no org '%s' registered — run 'flowmcp add %s' or 'connect %s' first" ;;
    msg_install_ok)       echo "installed '%s' into %s" ;;
    msg_install_note_mcpremote) echo "entry runs mcp-remote against Webflow's hosted MCP server — no token in this file, mcp-remote reads its own isolated session" ;;
    msg_install_note_pat) echo "entry references run-mcp.sh, not a literal token" ;;
    msg_install_restart)  echo "restart %s to pick it up" ;;
    msg_rename_new_exists) echo "org '%s' already exists — remove it first or pick a different name" ;;
    msg_rename_ok)        echo "renamed '%s' to '%s' — no re-login needed" ;;
    msg_rename_hint)      echo "restart any client whose config was just updated to pick up the rename" ;;
    msg_test_mcpremote_ok) echo "'%s' has a saved Webflow session (mcp-remote)" ;;
    msg_test_note1)       echo "note: this only confirms a session file exists on your computer —" ;;
    msg_test_note2)       echo "it doesn't check it against Webflow yet. That happens on its own when you" ;;
    msg_test_note3)       echo "open Claude Code, Claude Desktop, or Cursor: expired sessions refresh or re-prompt automatically." ;;
    msg_test_pat_ok)      echo "token for '%s' is valid · sites accessible: %s" ;;
    msg_test_scopes)      echo "scopes: %s" ;;
    msg_test_next_intro)  echo "install it into whichever client you're using:" ;;
    *)                    echo "$key" ;;
  esac
}
