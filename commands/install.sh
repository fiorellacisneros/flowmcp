#!/usr/bin/env bash
# Usage: webflow-workspaces install <org> <client> [--scope user|project] [--force]
# client: claude-code | claude-desktop | cursor
#
# Writes an mcpServers entry that points at run-mcp.sh, so the token itself
# never has to be written into the client's config file.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: webflow-workspaces install <org> <client> [--scope user|project] [--force]}"
client="${2:?Usage: webflow-workspaces install <org> <client> [--scope user|project] [--force]}"
shift 2
scope="user"
force=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) scope="$2"; shift 2 ;;
    --force) force="--force"; shift ;;
    *) echo "error: unknown option '$1'" >&2; exit 1 ;;
  esac
done

wfw_profile_exists "$org" || {
  wfw_say_err "no org '$org' registered — run 'webflow-workspaces add $org' or 'connect $org' first"
  exit 1
}

config_path="$(wfw_client_config_path "$client" "$scope")" || exit 1
auth_method="$(jq -r '.auth_method // "pat"' <<<"$(wfw_profile_read "$org")")"
server_name="webflow-$org"

server_json="$(wfw_build_server_json "$org" "$auth_method")"
if [[ "$auth_method" == "mcp-remote" ]]; then
  note="entry runs mcp-remote against Webflow's hosted MCP server — no token in this file, mcp-remote reads its own isolated session"
else
  note="entry references run-mcp.sh, not a literal token"
fi

wfw_client_merge_server "$config_path" "$server_name" "$server_json" "$force"
wfw_audit_log "install" "$org" "ok" "client=$client scope=$scope path=$config_path auth=$auth_method"

wfw_say_ok "installed '$server_name' into $config_path"
echo "${WFW_C_DIM}($note — restart $client to pick it up)${WFW_C_RESET}"
