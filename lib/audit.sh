#!/usr/bin/env bash
# Append-only audit log. Never write secret values here.

wfw_audit_log() {
  local action="$1" org="$2" result="$3" detail="${4:-}"
  local month file
  month="$(date -u +%Y-%m)"
  file="$WFW_AUDIT_DIR/$month.jsonl"
  jq -nc \
    --arg ts "$(wfw_now)" \
    --arg action "$action" \
    --arg org "$org" \
    --arg result "$result" \
    --arg detail "$detail" \
    '{ts: $ts, action: $action, org: $org, result: $result, detail: (if $detail == "" then null else $detail end)}' \
    >> "$file"
}
