#!/usr/bin/env bash
# Usage: flowmcp remove <org> --yes [--from client:scope ...] [--dry-run] [--json]
# Destructive: deletes the profile and the stored secret. Requires --yes.
# Optionally also strips the entry from named client configs, e.g.:
#   flowmcp remove acme --yes --from claude-code:user --from cursor:project

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: flowmcp remove <org> --yes [--from client:scope]... [--dry-run]}"
shift || true
confirmed=""
dry_run=""
json_flag=""
froms=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) confirmed="1"; shift ;;
    --from) froms+=("$2"); shift 2 ;;
    --dry-run) dry_run="1"; shift ;;
    --json) json_flag="1"; shift ;;
    *) echo "error: unknown option '$1'" >&2; exit 1 ;;
  esac
done

wfw_profile_exists "$org" || {
  wfw_say_err "no org '$org' registered"
  exit 1
}

if [[ -n "$dry_run" ]]; then
  targets=()
  for spec in "${froms[@]:-}"; do
    [[ -z "$spec" ]] && continue
    client="${spec%%:*}"; scope="${spec#*:}"
    config_path="$(wfw_client_config_path "$client" "$scope" 2>/dev/null || true)"
    [[ -n "$config_path" && -f "$config_path" ]] && targets+=("$config_path")
  done
  if wfw_json_mode "$json_flag"; then
    jq -nc --arg org "$org" --argjson targets "$(printf '%s\n' "${targets[@]:-}" | jq -R . | jq -sc 'map(select(length>0))')" \
      '{ok: true, dry_run: true, org: $org, would_delete: ["profile", "stored credentials"], would_strip_from: $targets}'
  else
    echo "${WFW_C_DIM}dry-run — would delete profile + stored credentials for '$org'${WFW_C_RESET}"
    for t in "${targets[@]:-}"; do echo "${WFW_C_DIM}would strip 'webflow-$org' from $t${WFW_C_RESET}"; done
  fi
  exit 0
fi

if [[ -z "$confirmed" ]]; then
  if wfw_json_mode "$json_flag"; then
    jq -nc --arg org "$org" '{ok: false, error: "confirmation required", next_steps: ["flowmcp remove \($org) --yes"]}'
  else
    wfw_say_err "this deletes the profile and the stored token for '$org'."
    wfw_say_hint "re-run with --yes to confirm"
    echo "${WFW_C_DIM}exit 1 · refused by a gate · nothing was deleted${WFW_C_RESET}" >&2
  fi
  exit 1
fi

removed_from=()
for spec in "${froms[@]:-}"; do
  [[ -z "$spec" ]] && continue
  client="${spec%%:*}"
  scope="${spec#*:}"
  config_path="$(wfw_client_config_path "$client" "$scope" 2>/dev/null || true)"
  if [[ -n "$config_path" && -f "$config_path" ]]; then
    wfw_client_remove_server "$config_path" "webflow-$org"
    removed_from+=("$config_path")
    wfw_json_mode "$json_flag" || wfw_say_ok "removed 'webflow-$org' from $config_path"
  fi
done

wfw_secret_delete "$org"
rm -rf "$(wfw_mcp_remote_dir "$org")"
wfw_profile_delete "$org"
wfw_audit_log "remove" "$org" "ok"

if wfw_json_mode "$json_flag"; then
  jq -nc --arg org "$org" --argjson removed "$(printf '%s\n' "${removed_from[@]:-}" | jq -R . | jq -sc 'map(select(length>0))')" \
    '{ok: true, dry_run: false, org: $org, removed_from: $removed}'
else
  wfw_say_ok "removed org '$org' (profile + stored credentials)"
fi
