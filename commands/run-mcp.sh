#!/usr/bin/env bash
# Usage: run-mcp.sh <org>
#
# NOT meant to be run by a human or an agent directly. This is what the
# `command` field in the generated mcpServers entry points to — the MCP
# client (Claude Code / Claude Desktop / Cursor) launches this at server
# start time. It looks up the token for <org> from the secret backend,
# exports it, and execs webflow-mcp-server. The token therefore never
# needs to appear in any client's config JSON file on disk.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=../lib/secrets.sh
source "$SCRIPT_DIR/../lib/secrets.sh"

org="${1:?Usage: run-mcp.sh <org>}"

WEBFLOW_TOKEN="$(wfw_secret_get "$org" || true)"
if [[ -z "$WEBFLOW_TOKEN" ]]; then
  echo "webflow-workspaces: no token stored for org '$org'. Run 'webflow-workspaces secret-set $org'." >&2
  exit 1
fi
export WEBFLOW_TOKEN

exec npx -y webflow-mcp-server@latest
