#!/usr/bin/env bash
# Usage: webflow-workspaces remove <org> --yes [--from client:scope ...]
# Destructive: deletes the profile and the stored secret. Requires --yes.
# Optionally also strips the entry from named client configs, e.g.:
#   webflow-workspaces remove acme --yes --from claude-code:user --from cursor:project

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: webflow-workspaces remove <org> --yes [--from client:scope]...}"
shift || true
confirmed=""
froms=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) confirmed="1"; shift ;;
    --from) froms+=("$2"); shift 2 ;;
    *) echo "error: unknown option '$1'" >&2; exit 1 ;;
  esac
done

wfw_profile_exists "$org" || {
  wfw_say_err "no org '$org' registered"
  exit 1
}

if [[ -z "$confirmed" ]]; then
  wfw_say_err "this deletes the profile and the stored token for '$org'."
  wfw_say_hint "re-run with --yes to confirm"
  echo "${WFW_C_DIM}exit 1 · refused by a gate · nothing was deleted${WFW_C_RESET}" >&2
  exit 1
fi

for spec in "${froms[@]:-}"; do
  [[ -z "$spec" ]] && continue
  client="${spec%%:*}"
  scope="${spec#*:}"
  config_path="$(wfw_client_config_path "$client" "$scope" 2>/dev/null || true)"
  if [[ -n "$config_path" && -f "$config_path" ]]; then
    wfw_client_remove_server "$config_path" "webflow-$org"
    wfw_say_ok "removed 'webflow-$org' from $config_path"
  fi
done

wfw_secret_delete "$org"
rm -rf "$(wfw_mcp_remote_dir "$org")"
wfw_profile_delete "$org"
wfw_audit_log "remove" "$org" "ok"

wfw_say_ok "removed org '$org' (profile + stored credentials)"
