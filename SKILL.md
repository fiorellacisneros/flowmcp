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
- `list`, `inspect`, `test`, and `debug` print structured JSON automatically
  whenever stdout isn't a real TTY — which includes every call you make
  through your Bash tool. You don't need to pass `--json` yourself; parse
  the output directly instead of scraping the colored human-readable text
  (that text only appears when a human is watching a real terminal).
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

## Two ways to connect an org — prefer `connect`

There are two paths to get a client's Webflow credentials registered.
**Prefer `connect` whenever a browser is available** — it's the one
non-technical users can do themselves with zero copy/paste and zero setup.
Fall back to the PAT path (`add` + `secret-set`) only for headless/remote
environments where no browser can be opened.

### `connect` (preferred, no setup required)

```
webflow-workspaces connect <org> --label "Acme Corp"
```

You can run this yourself, but it needs the user physically present: it
runs `npx mcp-remote` against Webflow's own hosted MCP server
(`mcp.webflow.com`), which opens a real browser, the client logs into
their own Webflow account and clicks approve, and the session is saved to
disk automatically. There is **no one-time app-registration step anymore**
— Webflow's hosted OAuth server supports Dynamic Client Registration, so
`mcp-remote` registers itself on the fly. No token ever touches your Bash
tool calls, stdout, or the conversation — you only see "connected" or
"failed", never a credential.

Because it needs a live Ctrl+C from the user once they see "connected" in
the output, tell them to run it themselves in their own terminal if you're
not driving an interactive session with them watching.

### PAT path (fallback): `add` + `secret-set`

1. `webflow-workspaces add <org> --label "Acme Corp"` — you can run this.
   Registers profile metadata only.
2. Tell the user, verbatim, to run in their own terminal:
   `webflow-workspaces secret-set <org>`
   Do not run this yourself. Do not ask them to paste the token into chat.

### Then, either path:

3. Verify with `webflow-workspaces test <org>` — you can run this; it hits
   the real Webflow API and reports back scopes/site count without ever
   printing the token.
4. Install into whichever client(s) the user wants:
   `webflow-workspaces install <org> claude-code --scope project`
   (or `claude-desktop` / `cursor`, `--scope user`). This merges into the
   existing config — it will not clobber other MCP servers already there,
   and refuses to overwrite an existing `webflow-<org>` entry unless you
   pass `--force` (confirm with the user before using `--force`).
5. Tell the user to restart the target client to pick up the new server.

## Workflow: something's not connecting

Run `webflow-workspaces debug <org>`. It branches on the org's
`auth_method` (`mcp-remote` or `pat`) and checks the right things for each:
profile exists, credentials exist (session file or keychain), the relevant
npm package (`mcp-remote` or `webflow-mcp-server`) is resolvable, a
credential check (reusing `test`), and whether known client config files
are valid JSON and contain the `webflow-<org>` entry. Read its output back
to the user — it never prints a token, so its full output is always safe
to relay verbatim.

Common causes:
- `mcp-remote` orgs: no saved session → tell the user to run
  `webflow-workspaces connect <org>` themselves. `test`/`debug` only check
  that a session was *saved*, not that it's still valid — an expired
  session refreshes or re-prompts automatically the next time a real
  client connects, so don't over-interpret an "ok" here as a guarantee.
- `pat` orgs: HTTP 401 → token invalid/revoked/expired → tell user to run
  `webflow-workspaces rotate <org>` themselves. HTTP 403 → token valid but
  missing scopes. HTTP 000 → network/DNS/proxy issue, not a token problem.
- client config exists but has no `webflow-<org>` entry → `install` wasn't
  run yet, or was run against a different scope/client than the user
  expects (check `--scope user` vs `--scope project`, and which client).

## Workflow: removing or rotating a client

- Rotate: PAT orgs — tell the user to run `webflow-workspaces rotate <org>`
  themselves, same TTY-only rule as `secret-set`. `mcp-remote` orgs don't
  need manual rotation — just re-run `connect <org>`, which overwrites the
  saved session.
- Remove: `webflow-workspaces remove <org> --yes [--from client:scope]...`
  is destructive (deletes the profile and the stored credentials — token
  or saved session, whichever applies) — confirm with the user before
  running it, and pass `--from claude-code:project` etc. for each client
  config you should also strip the entry from.

## Command reference

```
webflow-workspaces add <org> [--label "Name"]
webflow-workspaces secret-set <org>                 # human-only, TTY required
webflow-workspaces rotate <org>                     # human-only, TTY required
webflow-workspaces connect <org> [--label "Name"]   # opens a browser, needs the user present
webflow-workspaces list [--json]
webflow-workspaces inspect <org> [--live] [--json]
webflow-workspaces test <org> [--json]
webflow-workspaces install <org> <client> [--scope user|project] [--force]
                                                     # client: claude-code | claude-desktop | cursor
webflow-workspaces remove <org> --yes [--from client:scope]...
webflow-workspaces debug <org> [--json]
```

`--json` is implicit whenever stdout isn't a TTY, so you (the agent) get it by
default — the flag exists for a human who wants machine output in their own
terminal.

## Storage layout (for context, not something you normally touch directly)

- `~/.webflow-workspaces/profiles/<org>.json` — non-sensitive metadata only
  (label, created_at, `auth_method`, secret backend, last test
  result/scopes/error). Safe to `jq`/`cat`/show the user in full.
- `mcp-remote` orgs: `~/.webflow-workspaces/mcp-remote/<org>/` — an
  isolated `MCP_REMOTE_CONFIG_DIR` per org, owned and read entirely by the
  third-party `mcp-remote` tool. We only ever check whether a `*_tokens.json`
  file exists in there (`wfw_mcp_remote_connected`) — never read its
  contents.
- `pat` orgs: OS keychain first (`security` on macOS, `secret-tool`/libsecret
  on Linux), falling back to `~/.webflow-workspaces/secrets/<org>.token` at
  `chmod 600` only when no keychain is available (e.g. a headless
  container). Never read this file directly — always go through `test`,
  `inspect`, or `debug`, which are designed not to leak it.
- `~/.webflow-workspaces/audit/<YYYY-MM>.jsonl` — append-only log of actions
  with timestamps and results, never credential values. Useful if the user
  asks "when did we last touch the Acme connection."

## Why there's no more manual OAuth App setup

Earlier versions of this tool required creating a Webflow OAuth App by hand
(client_id/client_secret) because the classic Data API OAuth
(`api.webflow.com/oauth`) has no PKCE support — a shared secret couldn't be
shipped safely in an open-source package. That's no longer needed: Webflow
now hosts its own MCP server at `mcp.webflow.com` with a modern OAuth
server (PKCE + Dynamic Client Registration + refresh tokens), verified
directly against the real endpoint. `connect` uses that via `mcp-remote`
instead, which eliminates the manual setup step entirely. The tradeoff:
`mcp-remote` orgs only work with Webflow's *hosted* MCP server (its access
tokens don't work against `api.webflow.com` directly) and tokens expire
hourly (refreshed transparently by `mcp-remote`/the MCP client, not by us).
The PAT path still exists for headless environments or if raw Data API
access is ever needed outside of `mcp.webflow.com`'s tool surface.

## Extending to other MCP servers

The design isn't hardcoded to Webflow: `lib/secrets.sh`, `lib/profiles.sh`,
`lib/clients.sh` generalize to any provider. The `mcp-remote` path
generalizes to any remote MCP server with a spec-compliant OAuth server
(PKCE + DCR); the PAT path (`run-mcp.sh`) generalizes to any local MCP
server taking a single bearer-token env var. `$WFW_MCP_URL` in
`lib/common.sh` and the `webflow-mcp-server` reference in `run-mcp.sh` are
the two places with Webflow hardcoded today.
