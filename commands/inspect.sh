#!/usr/bin/env bash
# Usage: webflow-workspaces inspect <org> [--live] [--json]
# Prints full profile metadata (no token). Add --live to also re-run test.
# JSON automatically when stdout isn't a real TTY (e.g. an agent's tool call).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: webflow-workspaces inspect <org> [--live] [--json]}"
shift || true
live="" json_flag=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --live) live="1"; shift ;;
    --json) json_flag="1"; shift ;;
    *) echo "error: unknown option '$1'" >&2; exit 1 ;;
  esac
done

wfw_profile_exists "$org" || {
  echo "error: no org '$org' registered" >&2
  exit 1
}

if [[ -n "$live" ]]; then
  "$WFW_COMMANDS_DIR/test.sh" "$org" >/dev/null 2>&1 || true
fi

auth_method="$(jq -r '.auth_method // "pat"' <<<"$(wfw_profile_read "$org")")"
if [[ "$auth_method" == "mcp-remote" ]]; then
  wfw_mcp_remote_connected "$org" && connected="true" || connected="false"
else
  wfw_secret_exists "$org" && connected="true" || connected="false"
fi

if wfw_json_mode "$json_flag"; then
  if [[ "$connected" == "false" ]]; then
    if [[ "$auth_method" == "mcp-remote" ]]; then
      next="[\"webflow-workspaces connect $org\"]"
    else
      next="[\"webflow-workspaces secret-set $org\"]"
    fi
  else
    next="[\"webflow-workspaces test $org\"]"
  fi
  jq --argjson connected "$connected" --argjson next "$next" \
    '. + {connected: $connected, next_steps: $next}' "$(wfw_profile_path "$org")"
  exit 0
fi

jq . "$(wfw_profile_path "$org")"
echo
if [[ "$connected" == "false" ]]; then
  if [[ "$auth_method" == "mcp-remote" ]]; then
    echo "note: no saved session yet for '$org' — run 'webflow-workspaces connect $org'"
  else
    echo "note: no token stored yet for '$org' — run 'webflow-workspaces secret-set $org'"
  fi
fi
