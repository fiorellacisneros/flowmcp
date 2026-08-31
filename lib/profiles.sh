#!/usr/bin/env bash
# Non-sensitive profile metadata (org name, backend, last test result).
# Never store token values here — see lib/secrets.sh.

wfw_profile_exists() { [[ -f "$(wfw_profile_path "$1")" ]]; }

wfw_profile_write_new() {
  local org="$1" label="$2" backend
  backend="$(wfw_secret_backend)"
  jq -n \
    --arg org "$org" \
    --arg label "$label" \
    --arg created_at "$(wfw_now)" \
    --arg backend "$backend" \
    '{
      org: $org,
      label: $label,
      created_at: $created_at,
      secret_backend: $backend,
      last_test: { timestamp: null, status: null, scopes: [], sites_count: null, error: null }
    }' > "$(wfw_profile_path "$org")"
}

wfw_profile_read() { cat "$(wfw_profile_path "$1")"; }

wfw_profile_update_last_test() {
  local org="$1" status="$2" scopes_json="$3" sites_count="$4" error="$5"
  local p tmp
  p="$(wfw_profile_path "$org")"
  tmp="$(mktemp)"
  jq \
    --arg ts "$(wfw_now)" \
    --arg status "$status" \
    --argjson scopes "$scopes_json" \
    --argjson sites_count "$sites_count" \
    --arg error "$error" \
    '.last_test = { timestamp: $ts, status: $status, scopes: $scopes, sites_count: $sites_count, error: (if $error == "" then null else $error end) }' \
    "$p" > "$tmp" && mv "$tmp" "$p"
}

wfw_profile_delete() { rm -f "$(wfw_profile_path "$1")"; }

wfw_profile_list() {
  shopt -s nullglob
  for f in "$WFW_PROFILES_DIR"/*.json; do
    basename "$f" .json
  done
  shopt -u nullglob
}
