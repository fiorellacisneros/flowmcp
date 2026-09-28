#!/usr/bin/env bash
# Usage: run-mcp-remote.sh <org>     (also: flowmcp run-mcp-remote <org>)
#
# NOT meant to be run by a human or an agent. This is what a connect/OAuth
# org's mcpServers entry launches — the MCP client (Claude Code / Claude
# Desktop / Cursor) starts it instead of calling `npx mcp-remote` directly.
#
# A client-launched process runs unattended, so it must never ask a person
# to sign in. Left alone, mcp-remote does exactly that whenever a session is
# missing or rejected: it opens a browser tab, the client gives up after 30s
# and retries, and that repeats forever while each attempt also holds the
# shared local sign-in port. Here it can't:
#   - no saved session  -> fail once, immediately, with a message that says
#                          what to run (`flowmcp connect <org>`, in a terminal)
#   - session rejected  -> every browser opener is a no-op and the sign-in
#                          wait is capped at 5s, so it fails once and lets go
#                          of the port instead of blocking other logins
# Only `flowmcp connect` may open a browser.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export WFW_LIB_DIR="${WFW_LIB_DIR:-$SCRIPT_DIR/../lib}"
# shellcheck source=../lib/bootstrap.sh
source "$WFW_LIB_DIR/bootstrap.sh"

org="${1:?Usage: run-mcp-remote.sh <org>}"

if ! wfw_mcp_remote_connected "$org"; then
  wfw_audit_log "guardian" "$org" "fail" "launched without a saved session"
  wfw_t guardian_no_session "$org" "$org" >&2
  exit 1
fi

shims="$WFW_HOME/noopen"
mkdir -p "$shims"
for opener in open xdg-open gio x-www-browser sensible-browser; do
  if [[ ! -x "$shims/$opener" ]]; then
    printf '#!/bin/sh\nexit 0\n' > "$shims/$opener"
    chmod +x "$shims/$opener"
  fi
done

export PATH="$shims:$PATH" BROWSER=true
unset DISPLAY WAYLAND_DISPLAY DBUS_SESSION_BUS_ADDRESS
export MCP_REMOTE_CONFIG_DIR
MCP_REMOTE_CONFIG_DIR="$(wfw_mcp_remote_dir "$org")"

exec npx -y "mcp-remote@$WFW_MCP_REMOTE_VERSION" "$WFW_MCP_URL" --resource "$WFW_MCP_URL" --auth-timeout 5
