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
  echo "error: no org '$org' registered" >&2
  exit 1
}

if [[ -z "$confirmed" ]]; then
  echo "error: this deletes the profile and the stored token for '$org'. Re-run with --yes to confirm." >&2
  exit 1
fi

for spec in "${froms[@]:-}"; do
  [[ -z "$spec" ]] && continue
  client="${spec%%:*}"
  scope="${spec#*:}"
  config_path="$(wfw_client_config_path "$client" "$scope" 2>/dev/null || true)"
  if [[ -n "$config_path" && -f "$config_path" ]]; then
    wfw_client_remove_server "$config_path" "webflow-$org"
    echo "Removed 'webflow-$org' from $config_path"
  fi
done

wfw_secret_delete "$org"
wfw_profile_delete "$org"
wfw_audit_log "remove" "$org" "ok"

echo "Removed org '$org' (profile + stored token)."
