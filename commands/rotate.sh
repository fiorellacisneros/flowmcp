#!/usr/bin/env bash
# Usage: flowmcp rotate <org>
# Same interactive, human-only flow as secret-set — overwrites the existing
# token for an org that's already registered.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: flowmcp rotate <org>}"

wfw_profile_exists "$org" || {
  echo "error: no org '$org' registered" >&2
  exit 1
}

if [[ ! -t 0 ]]; then
  wfw_t msg_need_tty_rotate >&2
  wfw_t msg_run_yourself_short >&2
  exit 1
fi

wfw_t msg_rotate_enter "$org"
read -rs wfw_token_input
echo
if [[ -z "$wfw_token_input" ]]; then
  echo "error: empty token, aborting" >&2
  exit 1
fi

wfw_secret_set "$org" wfw_token_input
wfw_audit_log "rotate" "$org" "ok"

wfw_t msg_rotate_done "$org" "$(wfw_secret_backend)"
wfw_t msg_test_hint_new "$org"
