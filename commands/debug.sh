#!/usr/bin/env bash
# Usage: webflow-workspaces debug <org> [--json]
# Runs a battery of non-secret-leaking diagnostics and prints a summary.
# JSON automatically when stdout isn't a real TTY (e.g. an agent's tool call).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: webflow-workspaces debug <org> [--json]}"
shift || true
json_flag=""
[[ "${1:-}" == "--json" ]] && json_flag="1"

WFW_CHECKS=()

# wfw_check <name> <ok|fail|warn|note> <detail>
wfw_check() {
  local name="$1" level="$2" detail="$3"
  WFW_CHECKS+=("$(jq -nc --arg n "$name" --arg l "$level" --arg d "$detail" '{name:$n, level:$l, detail:$d}')")
  if ! wfw_json_mode "$json_flag"; then
    case "$level" in
      ok)   echo "ok: $detail" ;;
      fail) echo "FAIL: $detail" ;;
      warn) echo "WARN: $detail" ;;
      *)    echo "note: $detail" ;;
    esac
  fi
}

wfw_section() {
  wfw_json_mode "$json_flag" || echo "-- $1 --"
}

wfw_json_mode "$json_flag" || echo "== webflow-workspaces debug: $org =="

wfw_section "profile"
if wfw_profile_exists "$org"; then
  wfw_check "profile" "ok" "profile exists at $(wfw_profile_path "$org")"
else
  wfw_check "profile" "fail" "no profile registered. Run: webflow-workspaces add $org"
  if wfw_json_mode "$json_flag"; then
    jq -nc --arg org "$org" --argjson checks "$(printf '%s\n' "${WFW_CHECKS[@]}" | jq -sc '.')" \
      '{org: $org, checks: $checks}'
  fi
  exit 1
fi

auth_method="$(jq -r '.auth_method // "pat"' <<<"$(wfw_profile_read "$org")")"
wfw_json_mode "$json_flag" || echo "-- auth method: $auth_method --"

if [[ "$auth_method" == "mcp-remote" ]]; then
  if wfw_mcp_remote_connected "$org"; then
    wfw_check "session" "ok" "a saved mcp-remote session exists for '$org'"
  else
    wfw_check "session" "fail" "no saved session. Run: webflow-workspaces connect $org"
  fi
  wfw_section "mcp-remote availability"
  if command -v npx >/dev/null 2>&1; then
    if ver="$(npm view mcp-remote version 2>/dev/null)"; then
      wfw_check "mcp-remote" "ok" "reachable on npm (latest: $ver)"
    else
      wfw_check "mcp-remote" "warn" "could not reach npm registry to check mcp-remote (offline?)"
    fi
  else
    wfw_check "mcp-remote" "fail" "npx not found — install Node.js"
  fi
else
  backend="$(wfw_secret_backend)"
  wfw_section "secret backend: $backend"
  if wfw_secret_exists "$org"; then
    wfw_check "secret" "ok" "a token is stored for '$org'"
  else
    wfw_check "secret" "fail" "no token stored. Run: webflow-workspaces secret-set $org"
  fi
  wfw_section "webflow-mcp-server availability"
  if command -v npx >/dev/null 2>&1; then
    if ver="$(npm view webflow-mcp-server version 2>/dev/null)"; then
      wfw_check "webflow-mcp-server" "ok" "reachable on npm (latest: $ver)"
    else
      wfw_check "webflow-mcp-server" "warn" "could not reach npm registry to check webflow-mcp-server (offline?)"
    fi
  else
    wfw_check "webflow-mcp-server" "fail" "npx not found — install Node.js"
  fi
fi

wfw_section "credential check"
test_json="$("$WFW_COMMANDS_DIR/test.sh" "$org" --json 2>/dev/null || true)"
test_status="$(jq -r '.status // "fail"' <<<"$test_json" 2>/dev/null || echo fail)"
wfw_check "credentials" "$([[ "$test_status" == "ok" ]] && echo ok || echo fail)" "$(jq -r '.error // "valid"' <<<"$test_json" 2>/dev/null || echo "check failed")"
if ! wfw_json_mode "$json_flag"; then
  "$WFW_COMMANDS_DIR/test.sh" "$org" || true
fi

wfw_section "known client configs"
for spec in "claude-code:user" "claude-code:project" "claude-desktop:user" "cursor:user" "cursor:project"; do
  client="${spec%%:*}"; scope="${spec#*:}"
  path="$(wfw_client_config_path "$client" "$scope" 2>/dev/null || true)"
  [[ -z "$path" ]] && continue
  name="config:$spec"
  if [[ -f "$path" ]]; then
    if jq empty "$path" >/dev/null 2>&1; then
      has_entry="$(jq -r --arg n "webflow-$org" '.mcpServers[$n] // empty' "$path")"
      if [[ -n "$has_entry" ]]; then
        wfw_check "$name" "ok" "$path has 'webflow-$org' entry"
      else
        wfw_check "$name" "note" "$path exists, valid JSON, no 'webflow-$org' entry"
      fi
    else
      wfw_check "$name" "fail" "$path exists but is not valid JSON"
    fi
  else
    wfw_check "$name" "note" "$path does not exist"
  fi
done

if wfw_json_mode "$json_flag"; then
  jq -nc --arg org "$org" --argjson checks "$(printf '%s\n' "${WFW_CHECKS[@]}" | jq -sc '.')" \
    '{org: $org, checks: $checks}'
else
  echo "== done =="
fi
