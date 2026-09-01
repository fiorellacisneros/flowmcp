#!/usr/bin/env bash
# Usage: webflow-workspaces rename <old-org> <new-org>
# Renames an org: moves its profile and saved credentials without any
# re-authentication, and updates the entry name in any client config where
# it was already installed (server names are derived from the org name, so
# a rename has to touch those too, not just our own storage).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

old="${1:?Usage: webflow-workspaces rename <old-org> <new-org>}"
new="${2:?Usage: webflow-workspaces rename <old-org> <new-org>}"

wfw_valid_org "$new" || {
  wfw_say_err "org name must be lowercase alphanumeric with - or _ (got '$new')"
  exit 1
}

wfw_profile_exists "$old" || {
  wfw_say_err "no org '$old' registered"
  exit 1
}

if wfw_profile_exists "$new"; then
  wfw_say_err "org '$new' already exists — remove it first or pick a different name"
  exit 1
fi

auth_method="$(jq -r '.auth_method // "pat"' <<<"$(wfw_profile_read "$old")")"

jq --arg org "$new" '.org = $org' "$(wfw_profile_path "$old")" > "$(wfw_profile_path "$new")"
rm -f "$(wfw_profile_path "$old")"

if [[ "$auth_method" == "mcp-remote" ]]; then
  old_dir="$(wfw_mcp_remote_dir "$old")"
  new_dir="$(wfw_mcp_remote_dir "$new")"
  [[ -d "$old_dir" ]] && mv "$old_dir" "$new_dir"
else
  wfw_old_token="$(wfw_secret_get "$old" || true)"
  if [[ -n "$wfw_old_token" ]]; then
    wfw_secret_set "$new" wfw_old_token
    wfw_secret_delete "$old"
  fi
fi

updated=()
for spec in "claude-code:user" "claude-code:project" "claude-desktop:user" "cursor:user" "cursor:project"; do
  client="${spec%%:*}"; scope="${spec#*:}"
  path="$(wfw_client_config_path "$client" "$scope" 2>/dev/null || true)"
  [[ -z "$path" || ! -f "$path" ]] && continue
  jq empty "$path" >/dev/null 2>&1 || continue
  has_old="$(jq -r --arg n "webflow-$old" '.mcpServers[$n] // empty' "$path")"
  [[ -z "$has_old" ]] && continue
  server_json="$(wfw_build_server_json "$new" "$auth_method")"
  wfw_client_remove_server "$path" "webflow-$old"
  wfw_client_merge_server "$path" "webflow-$new" "$server_json" "--force"
  updated+=("$path")
done

wfw_audit_log "rename" "$old" "ok" "to=$new"

wfw_say_ok "renamed '$old' to '$new' — no re-login needed"
if [[ ${#updated[@]} -gt 0 ]]; then
  for p in "${updated[@]}"; do
    echo "${WFW_C_DIM}updated: $p (webflow-$old -> webflow-$new)${WFW_C_RESET}"
  done
  wfw_say_hint "restart any client whose config was just updated to pick up the rename"
fi
