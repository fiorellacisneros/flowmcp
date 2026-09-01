#!/usr/bin/env bash
# OAuth for the mcp-remote path: Webflow hosts its own MCP server at
# $WFW_MCP_URL with an OAuth server that supports Dynamic Client
# Registration + PKCE (no client_secret, no manual app to create — verified
# against the real endpoint). We don't implement the OAuth dance ourselves;
# `npx mcp-remote` (github.com/punkpeye/mcp-remote) already does PKCE, DCR,
# browser-opening, token storage, and refresh correctly. Our job is just to
# give each org an isolated MCP_REMOTE_CONFIG_DIR so their sessions never
# collide, and to check whether that directory holds a completed login.
#
# SECURITY NOTE: mcp-remote's on-disk token storage is outside our control
# (it's a third-party tool). We don't read or touch the token files
# ourselves — only check for their existence as a signal.

# wfw_mcp_remote_connected <org> — true if a completed OAuth session
# (access/refresh tokens, not just a half-finished PKCE attempt) exists.
wfw_mcp_remote_connected() {
  local dir
  dir="$(wfw_mcp_remote_dir "$1")"
  [[ -d "$dir" ]] || return 1
  find "$dir" -type f -name '*_tokens.json' 2>/dev/null | grep -q .
}
