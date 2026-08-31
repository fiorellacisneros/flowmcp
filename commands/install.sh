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
  echo "error: no org '$org' registered — run 'webflow-workspaces add $org' first" >&2
  exit 1
}

config_path="$(wfw_client_config_path "$client" "$scope")" || exit 1
run_mcp_path="$WFW_COMMANDS_DIR/run-mcp.sh"
chmod +x "$run_mcp_path" 2>/dev/null || true

server_name="webflow-$org"
server_json="$(jq -n --arg cmd "$run_mcp_path" --arg org "$org" \
  '{command: $cmd, args: [$org]}')"

wfw_client_merge_server "$config_path" "$server_name" "$server_json" "$force"
wfw_audit_log "install" "$org" "ok" "client=$client scope=$scope path=$config_path"

echo "Installed '$server_name' into $config_path"
echo "(entry references run-mcp.sh, not a literal token — restart $client to pick it up)"
