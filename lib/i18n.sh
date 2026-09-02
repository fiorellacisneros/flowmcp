#!/usr/bin/env bash
# Minimal i18n: detects/stores a human's language preference once, on their
# first interactive run. Never touches JSON output — agents always get
# English with fixed keys (see schema.sh). This only affects the
# human-readable --help/banner text a person actually reads.

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

# wfw_t <key> — looks up a human-facing message in the active language.
# English is the fallback for any key not yet translated, and for any
# unknown key (returns the key itself, so a typo is visible, not silent).
wfw_t() {
  local key="$1"
  if [[ "$(wfw_lang)" == "es" ]]; then
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
      *)                    wfw_t_en "$key" ;;
    esac
  else
    wfw_t_en "$key"
  fi
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
    *)                    echo "$key" ;;
  esac
}
