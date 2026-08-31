# webflow-workspaces

Manage multiple [`webflow-mcp-server`](https://www.npmjs.com/package/webflow-mcp-server)
connections — one per client — without ever letting a Webflow API token pass
through an AI agent's context.

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

## Install

```bash
git clone <this-repo> ~/.local/share/webflow-workspaces
ln -s ~/.local/share/webflow-workspaces/bin/webflow-workspaces /usr/local/bin/webflow-workspaces
```

Requires `bash`, `jq`, `curl`, and Node/`npx` (to run `webflow-mcp-server`
itself). On macOS the `security` CLI (ships with the OS) is used for
keychain access; on Linux install `libsecret-tools` (Debian/Ubuntu:
`apt install libsecret-tools`) for keychain support, or accept the
`chmod 600` file fallback.

To use it as a Claude Code skill, symlink or copy this repo into
`.claude/skills/webflow-workspaces/` (project-level) or
`~/.claude/skills/webflow-workspaces/` (user-level) — `SKILL.md` at the repo
root is the skill definition.

## Quick start

```bash
# 1. Register a client (agent-safe — no secret involved)
webflow-workspaces add acme --label "Acme Corp"

# 2. Store its token — run this yourself, in your own terminal.
#    It will NOT run non-interactively (e.g. via an agent's tool call).
webflow-workspaces secret-set acme

# 3. Verify it works
webflow-workspaces test acme

# 4. Install into a client
webflow-workspaces install acme claude-code --scope project
# or: claude-desktop | cursor, --scope user|project

# 5. Restart the target app to pick up the new MCP server.
```

## Commands

| Command | What it does |
|---|---|
| `add <org> [--label NAME]` | Register org metadata (no secret) |
| `secret-set <org>` | Interactively store a token (TTY only) |
| `rotate <org>` | Interactively replace a stored token (TTY only) |
| `list` | List orgs + last test status (no secrets) |
| `inspect <org> [--live]` | Show profile detail; `--live` re-runs `test` first |
| `test <org>` | Validate the stored token against the real Webflow API |
| `install <org> <client> [--scope user\|project] [--force]` | Merge an `mcpServers` entry into a client config |
| `remove <org> --yes [--from client:scope]...` | Delete profile + token, optionally strip client entries |
| `debug <org>` | Diagnose profile/secret/network/config issues |

Supported clients for `install`: `claude-code`, `claude-desktop`, `cursor`.

## How the token stays out of client configs

`install` doesn't write `{"env": {"WEBFLOW_TOKEN": "..."}}`. It writes:

```json
{
  "mcpServers": {
    "webflow-acme": {
      "command": "/path/to/webflow-workspaces/commands/run-mcp.sh",
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
~/.webflow-workspaces/
  profiles/<org>.json     # metadata only: label, created_at, backend, last test result
  secrets/<org>.token     # chmod 600, ONLY used when no OS keychain is available
  audit/<YYYY-MM>.jsonl   # append-only action log — no token values
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

## Extending to other MCP servers

The design isn't Webflow-specific by construction: `lib/secrets.sh`,
`lib/profiles.sh`, `lib/clients.sh`, and the `run-mcp.sh` wrapper pattern
generalize to any MCP server that authenticates via a single bearer-token
env var. `commands/run-mcp.sh` is the only file with `webflow-mcp-server`
hardcoded today.

## License

MIT — see [LICENSE](LICENSE).
