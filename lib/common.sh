#!/usr/bin/env bash
# Shared paths, env, and sanity checks for webflow-workspaces.
# Sourced by every command script. Never echo secrets from anything in lib/.

set -euo pipefail

WFW_HOME="${WFW_HOME:-$HOME/.webflow-workspaces}"
WFW_PROFILES_DIR="$WFW_HOME/profiles"
WFW_SECRETS_DIR="$WFW_HOME/secrets"     # only used by the file-fallback backend
WFW_AUDIT_DIR="$WFW_HOME/audit"
WFW_KEYCHAIN_SERVICE="webflow-workspaces"

wfw_ensure_dirs() {
  umask 077
  mkdir -p "$WFW_PROFILES_DIR" "$WFW_SECRETS_DIR" "$WFW_AUDIT_DIR"
}

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

wfw_valid_org() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9_-]*$ ]]
}

wfw_profile_path() { echo "$WFW_PROFILES_DIR/$1.json"; }

wfw_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

wfw_ensure_dirs
wfw_require_jq
