#!/usr/bin/env bash
# Usage: flowmcp list [--json]
# Lists registered orgs and their last test status. Never prints tokens.
# JSON automatically when stdout isn't a real TTY (e.g. an agent's tool call).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

json_flag=""
[[ "${1:-}" == "--json" ]] && json_flag="1"

orgs=($(wfw_profile_list))

if wfw_json_mode "$json_flag"; then
  if [[ ${#orgs[@]} -eq 0 ]]; then
    echo "[]"
    exit 0
  fi
  jq -sc '.' <(for org in "${orgs[@]}"; do wfw_profile_read "$org"; done)
  exit 0
fi

if [[ ${#orgs[@]} -eq 0 ]]; then
  wfw_t msg_no_orgs
  exit 0
fi

printf "${WFW_C_DIM}%-20s %-24s %-16s %-10s %s${WFW_C_RESET}\n" "ORG" "LABEL" "BACKEND" "LAST TEST" "TESTED AT"
for org in "${orgs[@]}"; do
  p="$(wfw_profile_read "$org")"
  label="$(jq -r '.label' <<<"$p")"
  backend="$(jq -r '.secret_backend' <<<"$p")"
  status="$(jq -r '.last_test.status // "never"' <<<"$p")"
  ts="$(jq -r '.last_test.timestamp // "-"' <<<"$p")"
  printf "%-20s %-24s %-16s %s %s\n" "$org" "$label" "$backend" "$(wfw_status_color_padded "$status" 10)" "$ts"
done
