#!/usr/bin/env bash
# Shared paths, env, and sanity checks for flowmcp.
# Sourced by every command script. Never echo secrets from anything in lib/.

set -euo pipefail

WFW_HOME="${WFW_HOME:-$HOME/.flowmcp}"
WFW_PROFILES_DIR="$WFW_HOME/profiles"
WFW_SECRETS_DIR="$WFW_HOME/secrets"     # only used by the file-fallback backend
WFW_AUDIT_DIR="$WFW_HOME/audit"
WFW_MCP_REMOTE_BASE_DIR="$WFW_HOME/mcp-remote"   # per-org isolated mcp-remote token storage
WFW_KEYCHAIN_SERVICE="flowmcp"
WFW_MCP_URL="https://mcp.webflow.com/mcp"        # Webflow's official hosted MCP server

wfw_ensure_dirs() {
  umask 077
  mkdir -p "$WFW_PROFILES_DIR" "$WFW_SECRETS_DIR" "$WFW_AUDIT_DIR" "$WFW_MCP_REMOTE_BASE_DIR"
}

# wfw_mcp_remote_dir <org> — isolated MCP_REMOTE_CONFIG_DIR so each org's
# OAuth session against the same mcp.webflow.com URL never collides with
# another org's.
wfw_mcp_remote_dir() { echo "$WFW_MCP_REMOTE_BASE_DIR/$1"; }

wfw_require_jq() {
  command -v jq >/dev/null 2>&1 || {
    echo "error: jq is required but not installed (https://jqlang.org)" >&2
    exit 1
  }
}

wfw_require_curl() {
  command -v curl >/dev/null 2>&1 || {
    echo "error: curl is required but not installed" >&2
    exit 1
  }
}

wfw_require_npx() {
  command -v npx >/dev/null 2>&1 || {
    echo "error: npx (Node.js) is required for the OAuth flow (connect) but not installed" >&2
    exit 1
  }
}

# wfw_json_mode <explicit-flag> — true if --json was passed OR stdout isn't
# a real TTY (piped, captured by an agent's tool call, redirected to a file).
# Lets every read command default to machine-readable output the moment a
# human isn't directly watching the terminal, without requiring the caller
# to know to pass --json.
wfw_json_mode() {
  [[ "$1" == "1" ]] && return 0
  [[ ! -t 1 ]] && return 0
  return 1
}

wfw_valid_org() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9_-]*$ ]]
}

wfw_profile_path() { echo "$WFW_PROFILES_DIR/$1.json"; }

wfw_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

wfw_ensure_dirs
wfw_require_jq
