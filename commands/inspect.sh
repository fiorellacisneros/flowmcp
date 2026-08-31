#!/usr/bin/env bash
# Usage: webflow-workspaces inspect <org>
# Prints full profile metadata (no token). Add --live to also re-run test.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: webflow-workspaces inspect <org>}"
shift || true
live=""
[[ "${1:-}" == "--live" ]] && live="1"

wfw_profile_exists "$org" || {
  echo "error: no org '$org' registered" >&2
  exit 1
}

if [[ -n "$live" ]]; then
  "$WFW_COMMANDS_DIR/test.sh" "$org" || true
fi

jq . "$(wfw_profile_path "$org")"
echo
if ! wfw_secret_exists "$org"; then
  echo "note: no token stored yet for '$org' — run 'webflow-workspaces secret-set $org'"
fi
