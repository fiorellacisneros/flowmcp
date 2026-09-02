#!/usr/bin/env bash
# Usage: flowmcp install <org> <client> [--scope user|project] [--force] [--dry-run] [--json]
# client: claude-code | claude-desktop | cursor
#
# Writes an mcpServers entry that points at run-mcp.sh, so the token itself
# never has to be written into the client's config file.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: flowmcp install <org> <client> [--scope user|project] [--force] [--dry-run]}"
client="${2:?Usage: flowmcp install <org> <client> [--scope user|project] [--force] [--dry-run]}"
shift 2
scope="user"
force=""
dry_run=""
json_flag=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) scope="$2"; shift 2 ;;
    --force) force="--force"; shift ;;
    --dry-run) dry_run="1"; shift ;;
    --json) json_flag="1"; shift ;;
    *) echo "error: unknown option '$1'" >&2; exit 1 ;;
  esac
done

wfw_profile_exists "$org" || {
  wfw_say_err "$(wfw_t msg_install_no_org "$org" "$org" "$org")"
  exit 1
}

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

wfw_client_merge_server "$config_path" "$server_name" "$server_json" "$force"
wfw_audit_log "install" "$org" "ok" "client=$client scope=$scope path=$config_path auth=$auth_method"

if wfw_json_mode "$json_flag"; then
  jq -nc --arg org "$org" --arg client "$client" --arg scope "$scope" --arg path "$config_path" \
    --arg name "$server_name" \
    '{ok: true, dry_run: false, org: $org, client: $client, scope: $scope, path: $path, server_name: $name,
      next_steps: ["restart \($client) to pick up the new server", "flowmcp test \($org)"]}'
else
  wfw_say_ok "$(wfw_t msg_install_ok "$server_name" "$config_path")"
  echo "${WFW_C_DIM}($note — $(wfw_t msg_install_restart "$client"))${WFW_C_RESET}"
fi
