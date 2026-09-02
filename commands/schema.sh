#!/usr/bin/env bash
# Usage: flowmcp schema
# Machine-readable description of every command: args, flags, and the JSON
# shape it emits in --json mode. Always JSON, regardless of TTY — an agent
# should be able to `flowmcp schema` once at the start of a
# session and know the whole surface without parsing --help text.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

jq -nc --arg version "$(wfw_version)" '
{
  schema_version: 1,
  cli_version: $version,
  commands: [
    {
      name: "connect",
      usage: "connect <org> [--label NAME]",
      mutates: true,
      requires_tty: true,
      description: "Add/reconnect an org via browser OAuth (mcp-remote, no setup needed).",
      output: null
    },
    {
      name: "add",
      usage: "add <org> [--label NAME]",
      mutates: true,
      requires_tty: false,
      description: "Register org metadata only, no secret.",
      output: null
    },
    {
      name: "secret-set",
      usage: "secret-set <org>",
      mutates: true,
      requires_tty: true,
      description: "Interactively paste a token. Refuses to run without a real TTY.",
      output: null
    },
    {
      name: "rotate",
      usage: "rotate <org>",
      mutates: true,
      requires_tty: true,
      description: "Replace a stored token. Refuses to run without a real TTY.",
      output: null
    },
    {
      name: "list",
      usage: "list [--json]",
      mutates: false,
      requires_tty: false,
      description: "List registered orgs and last test status.",
      output: {shape: "array", item: "profile"}
    },
    {
      name: "inspect",
      usage: "inspect <org> [--live] [--json]",
      mutates: false,
      requires_tty: false,
      description: "Show one profile in full, plus a connected boolean. --live re-runs test first.",
      output: {shape: "object", item: "profile + connected"}
    },
    {
      name: "test",
      usage: "test <org> [--json]",
      mutates: false,
      requires_tty: false,
      description: "Validate stored credentials (network call for pat orgs, file check for mcp-remote orgs).",
      output: {shape: "object", fields: ["org","auth_method","status","sites_count","scopes","error"]}
    },
    {
      name: "install",
      usage: "install <org> <client> [--scope user|project] [--force] [--dry-run] [--json]",
      mutates: true,
      requires_tty: false,
      destructive: false,
      description: "Merge an mcpServers entry into a client config. --dry-run prints the entry without writing.",
      clients: ["claude-code","claude-desktop","cursor"],
      output: {shape: "object", fields: ["ok","org","client","scope","path","dry_run"]}
    },
    {
      name: "remove",
      usage: "remove <org> --yes [--from client:scope]... [--dry-run] [--json]",
      mutates: true,
      requires_tty: false,
      destructive: true,
      description: "Delete profile + credentials, optionally strip client entries. Requires --yes, no prompt.",
      output: {shape: "object", fields: ["ok","org","removed_from","dry_run"]}
    },
    {
      name: "rename",
      usage: "rename <old-org> <new-org> [--dry-run] [--json]",
      mutates: true,
      requires_tty: false,
      destructive: false,
      description: "Move a profile + saved session to a new org name, no re-login, updates installed client configs.",
      output: {shape: "object", fields: ["ok","old","new","updated"]}
    },
    {
      name: "debug",
      usage: "debug <org> [--json]",
      mutates: false,
      requires_tty: false,
      description: "Diagnose profile/credential/network/config issues.",
      output: {shape: "object", fields: ["org","checks"]}
    },
    {
      name: "schema",
      usage: "schema",
      mutates: false,
      requires_tty: false,
      description: "This output.",
      output: {shape: "object", fields: ["schema_version","cli_version","commands"]}
    }
  ],
  conventions: {
    json_auto: "list/inspect/test/debug/install/remove/rename print JSON automatically when stdout is not a TTY, no --json flag required",
    next_steps_field: "JSON output includes next_steps: [string] where applicable — suggested commands to run next",
    exit_codes: {"0": "success", "1": "user error or failed check (org not found, gate refused, test failed)"},
    secrets: "no command ever accepts a token as an argument or prints one; secret-set/rotate require a real TTY"
  }
}
'
