#!/usr/bin/env bash
# Idempotent loader: makes every command script work whether it's
# `source`d by bin/webflow-workspaces (functions already in-process) or
# executed as its own subprocess (e.g. debug.sh shelling out to test.sh).
BOOTSTRAP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${WFW_LIB_DIR:=$BOOTSTRAP_LIB_DIR}"
: "${WFW_COMMANDS_DIR:=$BOOTSTRAP_LIB_DIR/../commands}"

if ! declare -f wfw_profile_exists >/dev/null 2>&1; then
  source "$WFW_LIB_DIR/common.sh"
  source "$WFW_LIB_DIR/secrets.sh"
  source "$WFW_LIB_DIR/profiles.sh"
  source "$WFW_LIB_DIR/audit.sh"
  source "$WFW_LIB_DIR/clients.sh"
  source "$WFW_LIB_DIR/oauth.sh"
  source "$WFW_LIB_DIR/ui.sh"
fi
