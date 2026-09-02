# flowmcp

Manage multiple [`webflow-mcp-server`](https://www.npmjs.com/package/webflow-mcp-server)
connections — one per client — without ever letting a Webflow API token pass
through an AI agent's context.

Built [by human, for human](https://www.forhuman.studio/).

## Install

```bash
npm install -g @forhuman/flowmcp
```

Installs both `flowmcp` and the short alias `fmcp`. Requires
`bash`, `jq`, `curl`, and Node/`npx`. On macOS the `security` CLI (ships with
the OS) is used for keychain access; on Linux install `libsecret-tools`
(Debian/Ubuntu: `apt install libsecret-tools`) for keychain support, or
accept the `chmod 600` file fallback.

## Quick start

```bash
fmcp connect acme --label "Acme Corp"
# opens your browser -> client approves access -> Ctrl+C once connected -> done

fmcp test acme
fmcp install acme claude-code --scope project
```

No OAuth App to create, no client ID/secret to manage — `connect` shells out
to [`mcp-remote`](https://www.npmjs.com/package/mcp-remote) against Webflow's
own hosted MCP server, which supports Dynamic Client Registration and PKCE.
No browser available (headless environment)? Use a manually-pasted token
instead:

```bash
fmcp add acme --label "Acme Corp"
fmcp secret-set acme     # run this yourself, in your own terminal — TTY only
fmcp test acme
fmcp install acme claude-code --scope project
# restart the target app to pick up the new MCP server
```

Ask `fmcp schema` for a machine-readable map of every command — usage, JSON
shape, whether it mutates, requires a TTY, or is destructive. That's the
first thing an agent driving this CLI should run.

## Why

If you run an agency, you need one Webflow API token per client workspace
(plus your own). MCP ties a connection to a single token, so a multi-client
setup means hand-editing `mcpServers` blocks in Claude Code / Claude Desktop
/ Cursor config for every client — and it's easy to end up with tokens
sitting in plaintext JSON files, or worse, pasted into an agent chat where
they land in logs forever.

This is a small CLI plus a [Claude Code skill](SKILL.md) that:

- registers one **profile** per org (label, metadata — no secret),
- stores the actual token in your **OS keychain** (macOS Keychain / Linux
  Secret Service via `secret-tool`), falling back to a `chmod 600` file only
  when no keychain is available,
- writes `mcpServers` entries that point at a small wrapper script which
  resolves the token from the keychain **at MCP-server launch time** — so no
  client config file ever contains a literal token,
- refuses to accept a token as a CLI argument or print one, ever. The only
  two commands that touch a token (`secret-set`, `rotate`) require a real
  interactive TTY and read it via a hidden `read -s` prompt.

This last point is the reason it exists as a *skill*, not just a script: an
AI agent driving your terminal should be able to add, list, test, install,
and debug connections on your behalf — but should never be in the loop for
the token itself.

## Commands

| Command | What it does |
|---|---|
| `add <org> [--label NAME]` | Register org metadata (no secret) |
| `secret-set <org>` | Interactively paste a token (TTY only) |
| `rotate <org>` | Interactively replace a stored token (TTY only) |
| `connect <org> [--label NAME]` | Add/reconnect an org via browser OAuth — no setup, needs the user present |
| `list [--json]` | List orgs + last test status (no secrets) |
| `inspect <org> [--live] [--json]` | Show profile detail; `--live` re-runs `test` first |
| `test <org> [--json]` | Validate the stored credentials |
| `install <org> <client> [--scope user\|project] [--force] [--dry-run] [--json]` | Merge an `mcpServers` entry into a client config |
| `remove <org> --yes [--from client:scope]... [--dry-run] [--json]` | Delete profile + credentials, optionally strip client entries |
| `rename <old-org> <new-org> [--dry-run] [--json]` | Rename an org — no re-login needed |
| `debug <org> [--json]` | Diagnose profile/credential/network/config issues |
| `schema` | Machine-readable reference of every command's usage and JSON output shape |

Supported clients for `install`: `claude-code`, `claude-desktop`, `cursor`.

`list`/`inspect`/`test`/`debug`/`install`/`remove`/`rename` print JSON
automatically whenever stdout isn't a real TTY (piped, redirected, or
invoked by an agent's tool call) — `--json` only matters when you want
machine output in your own terminal. JSON responses include a `next_steps`
array naming the follow-up command, when there is an obvious one.

`install`, `remove`, and `rename` are the only commands that touch a real,
shared client config file (Claude Code/Desktop/Cursor) — the one place here
where a wrong call has a real blast radius — so all three support `--dry-run`
to preview the change before it's written, and `remove` requires an explicit
`--yes` with no interactive fallback.

## For agents

Symlink or copy this repo into `.claude/skills/flowmcp/`
(project-level) or `~/.claude/skills/flowmcp/` (user-level) —
[`SKILL.md`](SKILL.md) at the repo root is the skill definition an agent
reads. It documents the same JSON contract as `fmcp schema`, plus the workflow
an agent should follow: never call `secret-set`/`rotate` on the user's
behalf, always check `fmcp schema` once per session instead of `--help`, and
prefer `--dry-run` before any `install`/`remove`/`rename` you're not certain
about.

## How credentials stay out of client configs

For `connect` (`mcp-remote`) orgs, `install` writes:

```json
{
  "mcpServers": {
    "webflow-acme": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://mcp.webflow.com/mcp", "--resource", "https://mcp.webflow.com/mcp"],
      "env": { "MCP_REMOTE_CONFIG_DIR": "/Users/you/.flowmcp/mcp-remote/acme" }
    }
  }
}
```

No credential of any kind is in that file — just a directory path.
`mcp-remote` reads its own isolated session from that directory (and
refreshes it) when the MCP client actually launches the server.

For `secret-set` (PAT) orgs, `install` instead writes:

```json
{
  "mcpServers": {
    "webflow-acme": {
      "command": "/path/to/flowmcp/commands/run-mcp.sh",
      "args": ["acme"]
    }
  }
}
```

`run-mcp.sh` is invoked by the MCP client itself (Claude Code / Claude
Desktop / Cursor) when it starts the server — not by you or by an agent. At
that point it looks up the token for `acme` from the keychain, exports it as
`WEBFLOW_TOKEN`, and `exec`s `npx -y webflow-mcp-server@latest`. The token
exists only in that child process's environment, for the lifetime of the
MCP session.

## Storage layout

```
~/.flowmcp/
  profiles/<org>.json       # metadata only: label, created_at, auth_method, last test result
  mcp-remote/<org>/         # mcp-remote orgs: isolated session storage, owned by mcp-remote itself
  secrets/<org>.token       # pat orgs: chmod 600, ONLY used when no OS keychain is available
  audit/<YYYY-MM>.jsonl     # append-only action log — no credential values
```

Metadata and secrets are physically separate files/stores, so profile data
can be freely read, printed, or committed to a private dotfiles repo without
any risk of exposing a token — never put `secrets/` under version control
(see `.gitignore`).

## Security model — what this does and doesn't protect against

- Protects against: tokens leaking into an AI agent's conversation
  transcript/logs, tokens sitting in plaintext in versioned config files,
  one client's token being usable to access another client's workspace.
- Does not protect against: a compromised local machine (keychain access
  is scoped to your OS user, not sandboxed further), a user manually
  pasting a token into chat despite the tool telling them not to, or
  `ps`-level visibility of `security add-generic-password -w <token>`'s
  argument for the brief instant `secret-set` invokes it on macOS (an
  inherent limitation of that CLI, not of this tool — it never happens
  through anything that logs).
- `connect` specifics: verified directly against `mcp.webflow.com`'s OAuth
  metadata (`.well-known/oauth-authorization-server`) that it supports PKCE
  (`S256`) and Dynamic Client Registration (`/oauth/register`, no
  approval required) — confirmed with a real registration + full PKCE
  token exchange. That's *specific to Webflow's hosted MCP server*, not
  Webflow's classic Data API OAuth (`api.webflow.com/oauth`), which still
  requires a `client_secret` with no PKCE alternative — which is why the
  PAT path exists rather than a client_secret-based OAuth flow for that API.
  The actual OAuth flow (PKCE, browser, token storage, refresh) is handled
  by the third-party [`mcp-remote`](https://www.npmjs.com/package/mcp-remote)
  tool, not by code in this repo — we only isolate each org's session into
  its own `MCP_REMOTE_CONFIG_DIR` and check for the presence of a
  `*_tokens.json` file as a "connected" signal, never reading its contents.

## Extending to other MCP servers

The design isn't Webflow-specific by construction: `lib/secrets.sh`,
`lib/profiles.sh`, and `lib/clients.sh` generalize to any provider. The
`connect`/`mcp-remote` path generalizes to any remote MCP server with a
spec-compliant OAuth server (PKCE + Dynamic Client Registration); the PAT
path (`run-mcp.sh`) generalizes to any local MCP server that authenticates
via a single bearer-token env var. `$WFW_MCP_URL` in `lib/common.sh` and
the `webflow-mcp-server` reference in `run-mcp.sh` are the two places with
Webflow hardcoded today.

## Links

- [SKILL.md](SKILL.md) — the agent-facing manual this CLI ships with
- [CONTRIBUTING.md](CONTRIBUTING.md) — layout, the one hard rule, how to test safely
- [cases/flowmcp.md](cases/flowmcp.md) — how this CLI was built, what broke, what got rejected
- Webflow MCP server: https://www.npmjs.com/package/webflow-mcp-server
- mcp-remote: https://www.npmjs.com/package/mcp-remote

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) — layout, the one non-negotiable rule
about tokens, and how to test against an isolated environment without ever
touching a real client's config.

## License

MIT — see [LICENSE](LICENSE).

---

Built by human, [forhuman](https://www.forhuman.studio/).
