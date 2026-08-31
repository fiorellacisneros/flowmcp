#!/usr/bin/env bash
# Resolves config file paths for supported MCP clients and merges the
# mcpServers block into them without clobbering unrelated entries.

wfw_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux) echo "linux" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

# wfw_client_config_path <client> <scope>
# client: claude-code | claude-desktop | cursor
# scope:  user | project   (project scope resolves relative to $PWD)
wfw_client_config_path() {
  local client="$1" scope="$2" os
  os="$(wfw_os)"
  case "$client" in
    claude-code)
      if [[ "$scope" == "project" ]]; then
        echo "$PWD/.mcp.json"
      else
        echo "$HOME/.claude.json"
      fi
      ;;
    claude-desktop)
      if [[ "$scope" == "project" ]]; then
        echo "error: claude-desktop has no project scope" >&2
        return 1
      fi
      case "$os" in
        macos) echo "$HOME/Library/Application Support/Claude/claude_desktop_config.json" ;;
        linux) echo "$HOME/.config/Claude/claude_desktop_config.json" ;;
        windows) echo "$APPDATA/Claude/claude_desktop_config.json" ;;
        *) echo "error: unsupported OS for claude-desktop" >&2; return 1 ;;
      esac
      ;;
    cursor)
      if [[ "$scope" == "project" ]]; then
        echo "$PWD/.cursor/mcp.json"
      else
        echo "$HOME/.cursor/mcp.json"
      fi
      ;;
    *)
      echo "error: unknown client '$client' (expected claude-code|claude-desktop|cursor)" >&2
      return 1
      ;;
  esac
}

# wfw_client_merge_server <config_path> <server_name> <server_json> [--force]
# Merges .mcpServers[server_name] = server_json into config_path, preserving
# every other key in the file. Refuses to overwrite an existing entry unless
# --force is passed. Creates parent dirs and a .bak backup of any existing file.
wfw_client_merge_server() {
  local config_path="$1" server_name="$2" server_json="$3" force="${4:-}"
  local dir tmp existing
  dir="$(dirname "$config_path")"
  mkdir -p "$dir"

  if [[ -f "$config_path" ]]; then
    if ! jq empty "$config_path" >/dev/null 2>&1; then
      echo "error: $config_path is not valid JSON — refusing to touch it" >&2
      return 1
    fi
    existing="$(jq -r --arg n "$server_name" '.mcpServers[$n] // empty' "$config_path")"
    if [[ -n "$existing" && "$force" != "--force" ]]; then
      echo "error: '$server_name' already exists in $config_path (use --force to overwrite)" >&2
      return 1
    fi
    cp "$config_path" "$config_path.bak"
  else
    echo '{}' > "$config_path"
  fi

  tmp="$(mktemp)"
  jq --arg n "$server_name" --argjson s "$server_json" \
    '.mcpServers = ((.mcpServers // {}) + {($n): $s})' \
    "$config_path" > "$tmp" && mv "$tmp" "$config_path"
}

wfw_client_remove_server() {
  local config_path="$1" server_name="$2" tmp
  [[ -f "$config_path" ]] || return 0
  tmp="$(mktemp)"
  jq --arg n "$server_name" 'if .mcpServers then .mcpServers |= del(.[$n]) else . end' \
    "$config_path" > "$tmp" && mv "$tmp" "$config_path"
}
