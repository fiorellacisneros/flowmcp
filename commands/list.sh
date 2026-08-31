#!/usr/bin/env bash
# Usage: webflow-workspaces list
# Lists registered orgs and their last test status. Never prints tokens.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

orgs=($(wfw_profile_list))
if [[ ${#orgs[@]} -eq 0 ]]; then
  echo "No orgs registered yet. Run 'webflow-workspaces add <org>' to start."
  exit 0
fi

printf "%-20s %-24s %-16s %-10s %s\n" "ORG" "LABEL" "BACKEND" "LAST TEST" "TESTED AT"
for org in "${orgs[@]}"; do
  p="$(wfw_profile_read "$org")"
  label="$(jq -r '.label' <<<"$p")"
  backend="$(jq -r '.secret_backend' <<<"$p")"
  status="$(jq -r '.last_test.status // "never"' <<<"$p")"
  ts="$(jq -r '.last_test.timestamp // "-"' <<<"$p")"
  printf "%-20s %-24s %-16s %-10s %s\n" "$org" "$label" "$backend" "$status" "$ts"
done
