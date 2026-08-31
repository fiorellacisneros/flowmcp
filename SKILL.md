---
name: webflow-workspaces
description: Manage multiple Webflow MCP server connections (one per client/org — e.g. an agency's own workspace plus each customer's) without ever letting an API token pass through agent context. Use when the user wants to add, list, inspect, test, install, rotate, remove, or debug a Webflow MCP connection, or asks to set up webflow-mcp-server for a new client, or reports an MCP connection to Webflow that isn't working.
license: MIT
---

# webflow-workspaces

A CLI (`bin/webflow-workspaces`) for managing one `webflow-mcp-server` connection
per client/org, so an agency can hold separate Webflow API tokens for its own
workspace and for each customer's workspace at once — installed into Claude
Code, Claude Desktop, and/or Cursor.

## The one rule that matters

**You (the agent) must never see, hold, echo, or transmit a real Webflow API
token.** Not as a Bash argument, not in a variable you print, not by asking
the user to paste it into chat. The tool is built so you never need to:

- `secret-set` and `rotate` are the *only* commands that touch a token, and
  both refuse to run unless invoked from a real interactive TTY (`read -s`
  hidden prompt). They will hard-fail if piped or run non-interactively —
  that's intentional, not a bug to work around.
- Every other command (`add`, `list`, `inspect`, `test`, `install`, `remove`,
  `debug`) only ever touches metadata or a keychain *reference*. Run these
  freely via your Bash tool.
- `install` never writes a literal token into a client's config file. It
  points the `command` field at `commands/run-mcp.sh <org>`, which looks the
  token up from the OS keychain (or the chmod-600 file fallback) at the
  moment the MCP client actually launches the server — long after your
  session has ended.

If a user asks you to "just paste the token in" or run `secret-set` for
them, don't. Tell them to run it themselves, in their own terminal, and
give them the exact command. Do not offer to run it "on their behalf" via
your Bash tool even if they insist — the TTY guard will reject it anyway,
but the point is to not try.

## Workflow: onboarding a new client

1. `webflow-workspaces add <org> --label "Acme Corp"` — you can run this.
   Registers profile metadata only.
2. Tell the user, verbatim, to run in their own terminal:
   `webflow-workspaces secret-set <org>`
   Do not run this yourself. Do not ask them to paste the token into chat.
3. Once they confirm it's done, verify with `webflow-workspaces test <org>`
   — you can run this; it hits the real Webflow API and reports back
   scopes/site count without ever printing the token.
4. Install into whichever client(s) the user wants:
   `webflow-workspaces install <org> claude-code --scope project`
   (or `claude-desktop` / `cursor`, `--scope user`). This merges into the
   existing config — it will not clobber other MCP servers already there,
   and refuses to overwrite an existing `webflow-<org>` entry unless you
   pass `--force` (confirm with the user before using `--force`).
5. Tell the user to restart the target client to pick up the new server.

## Workflow: something's not connecting

Run `webflow-workspaces debug <org>`. It checks: profile exists, secret
exists in the backend, `webflow-mcp-server` is resolvable via npm, a live
API call against the stored token (reusing `test`), and whether known
client config files are valid JSON and contain the `webflow-<org>` entry.
Read its output back to the user — it never prints the token, so its full
output is always safe to relay verbatim.

Common causes surfaced by `test`/`debug`:
- HTTP 401 → token invalid/revoked/expired → tell user to run
  `webflow-workspaces rotate <org>` themselves.
- HTTP 403 → token valid but missing scopes for the target site/workspace.
- HTTP 000 / no response → network/DNS/proxy issue, not a token problem.
- client config exists but has no `webflow-<org>` entry → `install` wasn't
  run yet, or was run against a different scope/client than the user
  expects (check `--scope user` vs `--scope project`, and which client).

## Workflow: removing or rotating a client

- Rotate: tell the user to run `webflow-workspaces rotate <org>` themselves,
  same TTY-only rule as `secret-set`.
- Remove: `webflow-workspaces remove <org> --yes [--from client:scope]...`
  is destructive (deletes the profile and the stored secret) — confirm with
  the user before running it, and pass `--from claude-code:project` etc.
  for each client config you should also strip the entry from.

## Command reference

```
webflow-workspaces add <org> [--label "Name"]
webflow-workspaces secret-set <org>                 # human-only, TTY required
webflow-workspaces rotate <org>                     # human-only, TTY required
webflow-workspaces list
webflow-workspaces inspect <org> [--live]
webflow-workspaces test <org>
webflow-workspaces install <org> <client> [--scope user|project] [--force]
                                                     # client: claude-code | claude-desktop | cursor
webflow-workspaces remove <org> --yes [--from client:scope]...
webflow-workspaces debug <org>
```

## Storage layout (for context, not something you normally touch directly)

- `~/.webflow-workspaces/profiles/<org>.json` — non-sensitive metadata only
  (label, created_at, secret backend in use, last test result/scopes/error).
  Safe to `jq`/`cat`/show the user in full.
- Token itself: OS keychain first (`security` on macOS, `secret-tool`/libsecret
  on Linux), falling back to `~/.webflow-workspaces/secrets/<org>.token` at
  `chmod 600` only when no keychain is available (e.g. a headless
  container). Never read this file directly — always go through `test`,
  `inspect`, or `debug`, which are designed not to leak it.
- `~/.webflow-workspaces/audit/<YYYY-MM>.jsonl` — append-only log of actions
  (add/secret-set/test/install/remove/rotate) with timestamps and results,
  never token values. Useful if the user asks "when did we last touch the
  Acme connection."

## Extending to other MCP servers

The architecture isn't hardcoded to Webflow: `lib/secrets.sh`,
`lib/profiles.sh`, `lib/clients.sh`, and the `run-mcp.sh` wrapper pattern
generalize to any MCP server that takes a single bearer-token-style env var.
`commands/run-mcp.sh` is the only file with `webflow-mcp-server` hardcoded
today — if asked to generalize, that's the one line to parameterize first.
