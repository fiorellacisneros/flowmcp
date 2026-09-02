#!/usr/bin/env bash
# Usage: flowmcp add <org> [--label "Display Name"]
# Registers profile metadata only. No token handling here — run
# `flowmcp secret-set <org>` yourself afterwards, in your own
# terminal, to store the token.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: flowmcp add <org> [--label \"Display Name\"]}"
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
  wfw_say_err "org '$org' already exists (use 'rotate' to change its token, or 'remove' first)"
  exit 1
fi

wfw_profile_write_new "$org" "$label"
wfw_audit_log "add" "$org" "ok"

backend="$(wfw_secret_backend)"
wfw_say_ok "registered org '$org' (label: $label) · secret backend: $backend"
echo
wfw_say_next "$(wfw_t msg_add_run_yourself)"
echo
echo "    flowmcp secret-set $org"
echo
echo "${WFW_C_DIM}$(wfw_t msg_add_explain1)"
echo "$(wfw_t msg_add_explain2 "$backend")"
echo "$(wfw_t msg_add_explain3)${WFW_C_RESET}"
