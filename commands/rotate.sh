#!/usr/bin/env bash
# Usage: webflow-workspaces rotate <org>
# Same interactive, human-only flow as secret-set — overwrites the existing
# token for an org that's already registered.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: webflow-workspaces rotate <org>}"

wfw_profile_exists "$org" || {
  echo "error: no org '$org' registered" >&2
  exit 1
}

if [[ ! -t 0 ]]; then
  echo "error: rotate requires an interactive terminal (stdin is not a TTY)." >&2
  echo "Run this command yourself in a real terminal window." >&2
  exit 1
fi

echo "Rotating token for '$org'. Enter the new Webflow API token (input hidden):"
read -rs wfw_token_input
echo
if [[ -z "$wfw_token_input" ]]; then
  echo "error: empty token, aborting" >&2
  exit 1
fi

wfw_secret_set "$org" wfw_token_input
wfw_audit_log "rotate" "$org" "ok"

echo "Rotated token for '$org' via $(wfw_secret_backend)."
echo "Run 'webflow-workspaces test $org' to verify the new token works."
