#!/usr/bin/env bash
# Usage: flowmcp install <org> <client> [--scope user|project] [--force] [--dry-run] [--json]
#                        [--allow-multiple-clients] [--remove-global]
# client: claude-code | claude-desktop | cursor
#
# Default scope is the CURRENT FOLDER for claude-code and cursor: run it from
# your client's folder and only sessions opened there load the org.
# claude-desktop only has a global config. --scope user installs the org for
# every session, in any folder.
#
# The entry written points at a launcher (see run-mcp-remote.sh / run-mcp.sh),
# so the token itself never has to be written into the client's config file.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

usage_line='Usage: flowmcp install <org> <client> [--scope user|project] [--force] [--dry-run] [--allow-multiple-clients] [--remove-global]'
org="${1:?$usage_line}"
client="${2:?$usage_line}"
shift 2
scope=""
force=""
dry_run=""
json_flag=""
allow_multi=""
remove_global=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) scope="$2"; shift 2 ;;
    --force) force="--force"; shift ;;
    --dry-run) dry_run="1"; shift ;;
    --json) json_flag="1"; shift ;;
    --allow-multiple-clients) allow_multi="1"; shift ;;
    --remove-global) remove_global="1"; shift ;;
    *) echo "error: unknown option '$1'" >&2; exit 1 ;;
  esac
done

# install_fail <message> <hint> <json next_steps array>
install_fail() {
  local msg="$1" hint="${2:-}" steps="${3:-[]}"
  if wfw_json_mode "$json_flag"; then
    jq -nc --arg e "$msg" --argjson n "$steps" '{ok: false, error: $e, next_steps: $n}'
  else
    wfw_say_err "$msg"
    if [[ -n "$hint" ]]; then wfw_say_hint "$hint"; fi
  fi
  exit 1
}

wfw_profile_exists "$org" || {
  wfw_say_err "$(wfw_t msg_install_no_org "$org" "$org" "$org")"
  exit 1
}

# A client we don't write configs for yet (Codex, Windsurf, Gemini CLI, ...):
# don't just fail — hand over the exact entry to paste into its MCP config.
case "$client" in
  claude-code|claude-desktop|cursor) ;;
  *)
    manual_auth="$(jq -r '.auth_method // "pat"' <<<"$(wfw_profile_read "$org")")"
    manual_entry="$(wfw_build_server_json "$org" "$manual_auth")"
    manual_json="$(jq -n --arg n "webflow-$org" --argjson e "$manual_entry" '{mcpServers: {($n): $e}}')"
    manual_toml="$(jq -r --arg n "webflow-$org" '"[mcp_servers.\($n)]\ncommand = \(.command | tojson)\nargs = \(.args | tojson)"' <<<"$manual_entry")"
    if wfw_json_mode "$json_flag"; then
      jq -nc --arg e "$(wfw_t msg_install_unsupported_short "$client")" --arg j "$manual_json" --arg t "$manual_toml" \
        '{ok: false, error: $e, supported_clients: ["claude-code","claude-desktop","cursor"], snippets: {json: $j, toml: $t},
          next_steps: ["paste a snippet into the client'"'"'s MCP config by hand"]}'
    else
      wfw_say_err "$(wfw_t msg_install_unsupported "$client")"
      echo
      echo "${WFW_C_DIM}$(wfw_t msg_install_unsupported_json)${WFW_C_RESET}"
      echo "$manual_json"
      echo
      echo "${WFW_C_DIM}$(wfw_t msg_install_unsupported_toml)${WFW_C_RESET}"
      echo "$manual_toml"
      echo
      wfw_say_hint "$(wfw_t msg_install_unsupported_note)"
    fi
    exit 1
    ;;
esac

if [[ -z "$scope" ]]; then
  if [[ "$client" == "claude-desktop" ]]; then
    scope="user"
  elif [[ "$PWD" == "$HOME" || "$PWD" == "/" ]]; then
    install_fail "$(wfw_t msg_install_need_folder)" "" \
      "$(jq -nc --arg o "$org" --arg c "$client" '["cd <your client folder>", "flowmcp install \($o) \($c)", "or, for every session: flowmcp install \($o) \($c) --scope user"]')"
  else
    scope="project"
  fi
fi

config_path="$(wfw_client_config_path "$client" "$scope")" || exit 1
auth_method="$(jq -r '.auth_method // "pat"' <<<"$(wfw_profile_read "$org")")"
server_name="webflow-$org"

server_json="$(wfw_build_server_json "$org" "$auth_method")"
if [[ "$auth_method" == "mcp-remote" ]]; then
  note="$(wfw_t msg_install_note_mcpremote)"
else
  note="$(wfw_t msg_install_note_pat)"
fi

if [[ -n "$dry_run" ]]; then
  if wfw_json_mode "$json_flag"; then
    jq -nc --arg org "$org" --arg client "$client" --arg scope "$scope" --arg path "$config_path" \
      --arg name "$server_name" --argjson entry "$server_json" \
      '{ok: true, dry_run: true, org: $org, client: $client, scope: $scope, path: $path,
        server_name: $name, entry: $entry, next_steps: ["flowmcp install \($org) \($client) --scope \($scope)"]}'
  else
    echo "${WFW_C_DIM}dry-run — would merge into $config_path:${WFW_C_RESET}"
    jq -n --arg name "$server_name" --argjson entry "$server_json" '{mcpServers: {($name): $entry}}'
  fi
  exit 0
fi

# Already installed exactly like this? Then there is nothing to change, and that
# is not an error. Present but different (usually written by an older version)
# still needs --force to overwrite.
skip_write=""
if [[ -f "$config_path" ]]; then
  existing="$(jq -c --arg n "$server_name" '.mcpServers[$n] // empty' "$config_path" 2>/dev/null || true)"
  if [[ -n "$existing" ]]; then
    if [[ "$(jq -cS . <<<"$existing")" == "$(jq -cS . <<<"$server_json")" ]]; then
      skip_write="1"
    elif [[ -z "$force" ]]; then
      install_fail "$(wfw_t msg_install_differs "$server_name" "$config_path")" "$(wfw_t msg_install_differs_hint)" \
        "$(jq -nc --arg o "$org" --arg c "$client" --arg s "$scope" '["flowmcp install \($o) \($c) --scope \($s) --force"]')"
    fi
  fi
fi

# One org, one client: two processes of the same org renew its Webflow login
# at the same moment and one of them destroys the session.
if [[ -z "$allow_multi" && -z "$skip_write" ]]; then
  others="$(wfw_org_installed_in "$org" | cut -d: -f1 | sort -u | grep -vx "$client" | paste -s -d, - | sed 's/,/, /g' || true)"
  if [[ -n "$others" ]]; then
    install_fail "$(wfw_t msg_install_multi "$org" "$others")" "$(wfw_t msg_install_multi_hint)" \
      "$(jq -nc --arg o "$org" --arg c "$client" '["keep \($o) in one client only", "flowmcp install \($o) \($c) --allow-multiple-clients"]')"
  fi
fi

# Moving to this folder: the same org may already be installed globally, where
# every session in every folder would keep loading it.
global_path=""
if [[ "$scope" == "project" && "$client" != "claude-desktop" ]]; then
  candidate="$(wfw_client_config_path "$client" user 2>/dev/null || true)"
  if [[ -n "$candidate" && -f "$candidate" ]] \
    && jq -e --arg n "$server_name" '.mcpServers[$n] // empty' "$candidate" >/dev/null 2>&1; then
    global_path="$candidate"
  fi
fi

if [[ -z "$skip_write" ]] && ! wfw_json_mode "$json_flag"; then
  if [[ "$scope" == "project" ]]; then
    echo "${WFW_C_DIM}$(wfw_t msg_install_plan_project "$config_path" "$client" "$org")${WFW_C_RESET}"
  else
    echo "${WFW_C_DIM}$(wfw_t msg_install_plan_user "$config_path" "$client")${WFW_C_RESET}"
  fi
fi

do_remove_global=""
global_hint=""
if [[ -n "$global_path" ]]; then
  if [[ -n "$remove_global" ]]; then
    do_remove_global="1"
  elif ! wfw_json_mode "$json_flag" && [[ -t 0 && -t 1 ]]; then
    wfw_say_warn "$(wfw_t msg_install_global_found "$global_path")"
    printf '%s' "$(wfw_t msg_install_global_ask)"
    read -r answer || answer=""
    case "$answer" in
      s|S|y|Y|si|sí|yes) do_remove_global="1" ;;
    esac
  else
    global_hint="1"
  fi
fi

if [[ -z "$skip_write" ]]; then
  wfw_client_merge_server "$config_path" "$server_name" "$server_json" "$force"
fi

removed_global=false
if [[ -n "$do_remove_global" ]]; then
  wfw_client_remove_server "$global_path" "$server_name"
  removed_global=true
fi
wfw_audit_log "install" "$org" "ok" "client=$client scope=$scope path=$config_path auth=$auth_method removed_global=$removed_global unchanged=${skip_write:-0}"

if wfw_json_mode "$json_flag"; then
  notes="[]"
  if [[ -n "$global_hint" ]]; then
    notes="$(jq -nc --arg p "$global_path" '["also installed in the global config (\($p)); run again with --remove-global to keep it only in this folder"]')"
  fi
  if [[ -n "$skip_write" ]]; then changed=false; else changed=true; fi
  jq -nc --arg org "$org" --arg client "$client" --arg scope "$scope" --arg path "$config_path" \
    --arg name "$server_name" --argjson removed_global "$removed_global" --argjson notes "$notes" \
    --argjson changed "$changed" \
    '{ok: true, dry_run: false, changed: $changed, org: $org, client: $client, scope: $scope, path: $path, server_name: $name,
      removed_global: $removed_global, notes: $notes,
      next_steps: ["restart \($client) to pick up the new server", "flowmcp list"]}'
else
  if [[ -n "$skip_write" ]]; then
    wfw_say_ok "$(wfw_t msg_install_already "$server_name" "$config_path")"
  else
    wfw_say_ok "$(wfw_t msg_install_ok "$server_name" "$config_path")"
  fi
  if [[ -n "$do_remove_global" ]]; then wfw_say_ok "$(wfw_t msg_install_global_removed "$global_path")"; fi
  if [[ -n "$global_hint" ]]; then
    wfw_say_warn "$(wfw_t msg_install_global_found "$global_path")"
    wfw_say_hint "$(wfw_t msg_install_global_hint)"
  fi
  if [[ -z "$skip_write" ]]; then
    echo "${WFW_C_DIM}($note — $(wfw_t msg_install_restart "$client"))${WFW_C_RESET}"
  fi
fi
