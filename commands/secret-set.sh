#!/usr/bin/env bash
# Usage: flowmcp secret-set <org>
#
# INTERACTIVE ONLY. This is the one command in this tool that must be run
# by a human, in their own terminal, never through an agent's tool-call
# interface — the token is read with a hidden prompt and never touches
# argv, stdout, or any log. If stdin isn't a real TTY, this refuses to run.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: flowmcp secret-set <org>}"

wfw_profile_exists "$org" || {
  echo "error: no org '$org' — run 'flowmcp add $org' first" >&2
  exit 1
}

if [[ ! -t 0 ]]; then
  wfw_t msg_need_tty_secret >&2
  wfw_t msg_run_yourself1 >&2
  wfw_t msg_run_yourself2 >&2
  exit 1
fi

wfw_t msg_secretset_enter "$org"
read -rs wfw_token_input
echo
if [[ -z "$wfw_token_input" ]]; then
  echo "error: empty token, aborting" >&2
  exit 1
fi

wfw_secret_set "$org" wfw_token_input
wfw_audit_log "secret-set" "$org" "ok"

wfw_t msg_secretset_stored "$org" "$(wfw_secret_backend)"
wfw_t msg_test_hint "$org"
