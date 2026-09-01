#!/usr/bin/env bash
# Usage: webflow-workspaces add <org> [--label "Display Name"]
# Registers profile metadata only. No token handling here — run
# `webflow-workspaces secret-set <org>` yourself afterwards, in your own
# terminal, to store the token.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: webflow-workspaces add <org> [--label \"Display Name\"]}"
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
wfw_say_next "run this yourself, in your own terminal (not through an agent):"
echo
echo "    webflow-workspaces secret-set $org"
echo
echo "${WFW_C_DIM}It will prompt for the Webflow API token with hidden input and store it"
echo "directly in $backend. The token is never passed as a command argument"
echo "and never printed.${WFW_C_RESET}"
