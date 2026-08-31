#!/usr/bin/env bash
# Usage: webflow-workspaces test <org>
# Validates the stored token against the real Webflow API. The token is
# read into a local variable and used only in an Authorization header —
# it is never echoed, logged, or included in any error message.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: webflow-workspaces test <org>}"
wfw_require_curl

wfw_profile_exists "$org" || {
  echo "error: no org '$org' registered" >&2
  exit 1
}

wfw_token="$(wfw_secret_get "$org")"
if [[ -z "$wfw_token" ]]; then
  echo "error: no token stored for '$org' — run 'webflow-workspaces secret-set $org'" >&2
  wfw_profile_update_last_test "$org" "fail" "[]" "null" "no token stored"
  exit 1
fi

body_file="$(mktemp)"
trap 'rm -f "$body_file"; unset wfw_token' EXIT

http_code="$(curl -s -o "$body_file" -w "%{http_code}" \
  -H "Authorization: Bearer $wfw_token" \
  -H "accept: application/json" \
  "https://api.webflow.com/v2/sites")"

if [[ "$http_code" == "200" ]]; then
  sites_count="$(jq '.sites | length' "$body_file" 2>/dev/null || echo 0)"

  scopes_json="[]"
  auth_body_file="$(mktemp)"
  auth_code="$(curl -s -o "$auth_body_file" -w "%{http_code}" \
    -H "Authorization: Bearer $wfw_token" \
    -H "accept: application/json" \
    "https://api.webflow.com/v2/token/authorized_by")"
  if [[ "$auth_code" == "200" ]] && jq -e '.scope' "$auth_body_file" >/dev/null 2>&1; then
    scopes_json="$(jq -c '.scope | split(" ")' "$auth_body_file")"
  fi
  rm -f "$auth_body_file"

  wfw_profile_update_last_test "$org" "ok" "$scopes_json" "$sites_count" ""
  wfw_audit_log "test" "$org" "ok" "sites=$sites_count"
  echo "OK: token for '$org' is valid. Sites accessible: $sites_count."
  if [[ "$scopes_json" != "[]" ]]; then
    echo "Scopes: $(jq -r 'join(", ")' <<<"$scopes_json")"
  fi
else
  err_msg="HTTP $http_code"
  detail="$(jq -r '.message // empty' "$body_file" 2>/dev/null || true)"
  [[ -n "$detail" ]] && err_msg="$err_msg: $detail"
  wfw_profile_update_last_test "$org" "fail" "[]" "null" "$err_msg"
  wfw_audit_log "test" "$org" "fail" "$err_msg"
  echo "FAIL: $err_msg" >&2
  case "$http_code" in
    401) echo "hint: token is invalid, revoked, or expired — try 'webflow-workspaces rotate $org'" >&2 ;;
    403) echo "hint: token is valid but lacks required scopes for this site/workspace" >&2 ;;
    000) echo "hint: no response — check network connectivity / DNS / proxy" >&2 ;;
  esac
  exit 1
fi
