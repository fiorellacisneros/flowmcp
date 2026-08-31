#!/usr/bin/env bash
# Usage: webflow-workspaces debug <org>
# Runs a battery of non-secret-leaking diagnostics and prints a summary.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

org="${1:?Usage: webflow-workspaces debug <org>}"

echo "== webflow-workspaces debug: $org =="

echo "-- profile --"
if wfw_profile_exists "$org"; then
  echo "ok: profile exists at $(wfw_profile_path "$org")"
else
  echo "FAIL: no profile registered. Run: webflow-workspaces add $org"
  exit 1
fi

echo "-- secret backend --"
backend="$(wfw_secret_backend)"
echo "backend in use: $backend"
if wfw_secret_exists "$org"; then
  echo "ok: a token is stored for '$org'"
else
  echo "FAIL: no token stored. Run: webflow-workspaces secret-set $org"
fi

echo "-- webflow-mcp-server availability --"
if command -v npx >/dev/null 2>&1; then
  if npm view webflow-mcp-server version >/dev/null 2>&1; then
    ver="$(npm view webflow-mcp-server version 2>/dev/null)"
    echo "ok: webflow-mcp-server is reachable on npm (latest: $ver)"
  else
    echo "WARN: could not reach npm registry to check webflow-mcp-server (offline?)"
  fi
else
  echo "FAIL: npx not found — install Node.js"
fi

echo "-- live API test --"
if wfw_secret_exists "$org"; then
  "$WFW_COMMANDS_DIR/test.sh" "$org" || true
else
  echo "skipped (no token stored)"
fi

echo "-- known client configs --"
for spec in "claude-code:user" "claude-code:project" "claude-desktop:user" "cursor:user" "cursor:project"; do
  client="${spec%%:*}"; scope="${spec#*:}"
  path="$(wfw_client_config_path "$client" "$scope" 2>/dev/null || true)"
  [[ -z "$path" ]] && continue
  if [[ -f "$path" ]]; then
    if jq empty "$path" >/dev/null 2>&1; then
      has_entry="$(jq -r --arg n "webflow-$org" '.mcpServers[$n] // empty' "$path")"
      if [[ -n "$has_entry" ]]; then
        echo "ok: $path has 'webflow-$org' entry"
      else
        echo "note: $path exists, valid JSON, no 'webflow-$org' entry"
      fi
    else
      echo "FAIL: $path exists but is not valid JSON"
    fi
  else
    echo "note: $path does not exist"
  fi
done

echo "== done =="
