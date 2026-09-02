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
    tagline)              echo "administrador de conexiones MCP a Webflow, seguro para agentes" ;;
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
    *)                    wfw_t_en "$key" ;;
  esac
}

wfw_t_en() {
  local key="$1"
  case "$key" in
    tagline)              echo "agent-safe Webflow MCP connection manager" ;;
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
    *)                    echo "$key" ;;
  esac
}
