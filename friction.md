# friction.md

Written retrospectively (this file should have been opened on day one — see
the case entry for that admission). Kept going forward for anything that
turns out wrong for this domain.

## Contract origin

Mixed. `lib/profiles.sh` / `lib/secrets.sh` / `lib/clients.sh` are a defined
contract — we own the shape of a "profile" and a "client config entry".
The OAuth surface (`mcp.webflow.com`'s `.well-known/oauth-authorization-server`,
DCR at `/oauth/register`, PKCE support) was discovered, not assumed — verified
live with a real registration + full token exchange before writing `connect`
against it, rather than guessing at Webflow's OAuth behavior from docs.

## Rejected

- **Hand-rolled OAuth (PKCE + refresh + local callback server).** Built once,
  worked, then thrown away in favor of shelling out to `mcp-remote`
  (github.com/punkpeye/mcp-remote). Reason: it already solves this exact
  problem (stdio↔remote-HTTP-MCP OAuth proxy) and is what the MCP ecosystem
  actually uses — re-implementing token refresh and SSE proxying ourselves
  was surface area with no payoff. The one thing we still own is per-org
  isolation, via `MCP_REMOTE_CONFIG_DIR`.
- **Custom OAuth App setup step (client_id/secret the user creates by hand).**
  Assumed necessary at first because that's how Webflow's classic Data API
  OAuth (`api.webflow.com/oauth`) works — no PKCE alternative there. Turned
  out false for the hosted MCP server specifically: `mcp.webflow.com`
  supports Dynamic Client Registration, so `connect` needed zero setup.
  Confirmed by reading the metadata endpoint, not by assumption.
- **`flowmcp` as a Claude-Code-only tool.** Considered scoping
  install targets to just `claude-code`. Rejected once it became clear the
  actual pain point (Claude Desktop's native Connector supporting only one
  Webflow account) lives in Claude Desktop, not Claude Code — `install`
  needed `claude-desktop` and `cursor` from the start.

## What turned out wrong

- **Test-org naming.** Used a throwaway name (`aktis-juanpa`) during manual
  testing of `rename` that collided with a real, already-connected client
  org of the same name. `rename`'s client-config scan resolves through the
  real `$HOME` (by design — `install`/`remove`/`rename` are meant to touch
  real, shared, global client config files), so it silently repointed a real
  entry in the user's real Claude Desktop config at a fake session directory.
  Recovered via `wfw_client_merge_server`'s own `.bak` backup, no data lost.
  Fix going forward: test org names must be obviously fake (`zzz-test-*`)
  and functional tests must run under an isolated `WFW_HOME`/`HOME`, not the
  real ones — see the test blocks now embedded in the build for `schema`,
  `--dry-run`, and `next_steps`.
- **`set -e` swallowing errors on command substitution.** Recurred four
  separate times (`wfw_secret_get` in `test.sh`, `run-mcp.sh`, and the
  `wfw_wait_with_logo`/`wait` pattern in `lib/ui.sh`): assigning the output
  of a command that can fail, without wrapping it in `if`/`|| true`, kills
  the whole script silently before the intended error handling runs. Now a
  standing check whenever a new command script reads a keychain value.

## Conventions this build confirms

- `--json` automatically on non-TTY stdout, no flag required — implemented
  across every read command (`list`/`inspect`/`test`/`debug`) plus every
  write command that now also supports `--json` (`install`/`remove`/`rename`).
- `next_steps` in structured output, so an agent isn't left to guess the
  follow-up command from prose it may not even be shown.
- `schema` command, versioned (`schema_version`), listing every command's
  usage, JSON output shape, and whether it mutates/requires a TTY/is
  destructive — added specifically because the skill flagged it as the
  highest-value, least-adopted convention in its corpus.
