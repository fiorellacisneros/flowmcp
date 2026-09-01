#!/usr/bin/env bash
# Usage: webflow-workspaces connect <org> [--label "Name"]
#
# Human-friendly alternative to add + secret-set: opens a browser, the
# client logs into their own Webflow account and approves access, and the
# session is captured automatically — no copy/paste of a token by anyone,
# ever, and no setup step required beforehand.
#
# Under the hood this runs `npx mcp-remote` against Webflow's own hosted
# MCP server (mcp.webflow.com), which handles the full OAuth dance itself
# (dynamic client registration, PKCE, browser open, token refresh) — we
# just give each org an isolated storage directory so sessions never mix.
# Must be run interactively (it opens a real browser and waits for you).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"
wfw_require_npx

org="${1:?Usage: webflow-workspaces connect <org> [--label \"Name\"]}"
shift || true
label="$org"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) label="$2"; shift 2 ;;
    *) echo "error: unknown option '$1'" >&2; exit 1 ;;
  esac
done

wfw_valid_org "$org" || {
  wfw_say_err "org name must be lowercase alphanumeric with - or _ (got '$org')"
  exit 1
}

if wfw_profile_exists "$org"; then
  echo "${WFW_C_DIM}reconnecting existing org '$org'...${WFW_C_RESET}"
else
  wfw_profile_write_new "$org" "$label" "mcp-remote"
fi

remote_dir="$(wfw_mcp_remote_dir "$org")"
mkdir -p "$remote_dir"

echo "Opening your browser for '$org' to approve access to Webflow..."
echo "Once you see it connect below, press Ctrl+C to return here — your"
echo "session is already saved to disk by that point."
echo

trap '' INT   # let mcp-remote (child) react to Ctrl+C; don't let it kill this script too
MCP_REMOTE_CONFIG_DIR="$remote_dir" npx -y mcp-remote "$WFW_MCP_URL" --resource "$WFW_MCP_URL" || true
trap - INT

if wfw_mcp_remote_connected "$org"; then
  wfw_profile_set_auth_method "$org" "mcp-remote"
  wfw_audit_log "connect" "$org" "ok"
  wfw_say_ok "connected '$org' via Webflow's OAuth"
  wfw_say_next "webflow-workspaces test $org — or 'install $org <client>' to wire it up"
else
  wfw_audit_log "connect" "$org" "fail" "no completed session found"
  wfw_say_err "no completed session found for '$org' — the login may not have finished"
  wfw_say_hint "run 'webflow-workspaces connect $org' again and wait until it shows connected"
  exit 1
fi
