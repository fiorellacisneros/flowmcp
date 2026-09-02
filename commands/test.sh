#!/usr/bin/env bash
# Usage: flowmcp test <org> [--json]
# Validates the stored credentials. For "pat" orgs, the token is read into
# a local variable and used only in an Authorization header — it is never
# echoed, logged, or included in any error message. For "mcp-remote" orgs
# we deliberately don't make a live call here (it could trigger mcp-remote
# to silently pop open a browser if the session needs re-auth) — we just
# check that a completed session exists on disk.
# JSON automatically when stdout isn't a real TTY (e.g. an agent's tool call).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: flowmcp test <org> [--json]}"
shift || true
json_flag=""
[[ "${1:-}" == "--json" ]] && json_flag="1"

wfw_profile_exists "$org" || {
  if wfw_json_mode "$json_flag"; then
    jq -nc --arg org "$org" '{org: $org, status: "fail", error: "org not registered"}'
  else
    wfw_say_err "no org '$org' registered"
  fi
  exit 1
}

auth_method="$(jq -r '.auth_method // "pat"' <<<"$(wfw_profile_read "$org")")"

# wfw_test_emit <status> <hint> — final output in whichever mode was requested.
wfw_test_emit() {
  local status="$1" hint="${2:-}"
  if wfw_json_mode "$json_flag"; then
    local next_hint="$hint"
    [[ "$status" == "ok" ]] && next_hint="flowmcp install $org <client>"
    jq -nc \
      --arg org "$org" --arg auth "$auth_method" --arg status "$status" \
      --arg error "$err_msg" --argjson scopes "${scopes_json:-[]}" \
      --argjson sites "${sites_count:-null}" --arg next_hint "$next_hint" \
      '{org: $org, auth_method: $auth, status: $status,
        sites_count: $sites, scopes: $scopes,
        error: (if $error == "" then null else $error end),
        next_steps: (if $next_hint == "" then [] else [$next_hint] end)}'
  else
    if [[ "$status" == "ok" ]]; then
      if [[ "$auth_method" == "mcp-remote" ]]; then
        wfw_say_ok "'$org' has a saved Webflow session (mcp-remote)"
        echo "${WFW_C_DIM}note: this only checks a session was saved, not that it's still valid —${WFW_C_RESET}"
        echo "${WFW_C_DIM}a real client (Claude Code/Cursor/Claude Desktop) will refresh or${WFW_C_RESET}"
        echo "${WFW_C_DIM}re-prompt automatically the next time it connects.${WFW_C_RESET}"
      else
        wfw_say_ok "token for '$org' is valid · sites accessible: $sites_count"
        [[ "$scopes_json" != "[]" ]] && echo "${WFW_C_DIM}scopes: $(jq -r 'join(", ")' <<<"$scopes_json")${WFW_C_RESET}"
      fi
    else
      wfw_say_err "$err_msg"
      [[ -n "$hint" ]] && wfw_say_hint "$hint"
    fi
  fi
}

err_msg="" scopes_json="[]" sites_count="null"

if [[ "$auth_method" == "mcp-remote" ]]; then
  if wfw_mcp_remote_connected "$org"; then
    wfw_profile_update_last_test "$org" "ok" "[]" "null" ""
    wfw_audit_log "test" "$org" "ok" "mcp-remote session present"
    wfw_test_emit "ok"
    exit 0
  else
    err_msg="no mcp-remote session found"
    wfw_profile_update_last_test "$org" "fail" "[]" "null" "$err_msg"
    wfw_audit_log "test" "$org" "fail" "$err_msg"
    wfw_test_emit "fail" "run 'flowmcp connect $org' to log in"
    exit 1
  fi
fi

wfw_require_curl

wfw_token="$(wfw_secret_get "$org" || true)"
if [[ -z "$wfw_token" ]]; then
  err_msg="no token stored"
  wfw_profile_update_last_test "$org" "fail" "[]" "null" "$err_msg"
  wfw_test_emit "fail" "run 'flowmcp secret-set $org'"
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
  wfw_test_emit "ok"
else
  err_msg="HTTP $http_code"
  detail="$(jq -r '.message // empty' "$body_file" 2>/dev/null || true)"
  [[ -n "$detail" ]] && err_msg="$err_msg: $detail"
  wfw_profile_update_last_test "$org" "fail" "[]" "null" "$err_msg"
  wfw_audit_log "test" "$org" "fail" "$err_msg"
  hint=""
  case "$http_code" in
    401) hint="token is invalid, revoked, or expired — try 'flowmcp rotate $org'" ;;
    403) hint="token is valid but lacks required scopes for this site/workspace" ;;
    000) hint="no response — check network connectivity / DNS / proxy" ;;
  esac
  wfw_test_emit "fail" "$hint"
  exit 1
fi
