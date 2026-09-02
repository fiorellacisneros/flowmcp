# case: flowmcp

**Target:** `flowmcp` itself (own repo, not a wrapped third party
in the sense the rest of this file means it — see "contract origin" below).
**Terrain:** mixed — a defined local contract (profiles, secrets, client
config entries) plus a discovered remote one (Webflow's hosted MCP server
OAuth surface).
**Distribution:** npm (`@forhuman/flowmcp`), bash + Node/`npx`
runtime, `bin` aliases `flowmcp` and `fmcp`. Chosen because the
audience is JS-ecosystem developers/agencies already running Node for
`npx mcp-remote` / `npx webflow-mcp-server` anyway — a compiled binary would
have added packaging cost with no reachability gain for this audience.

## Contract origin

Mixed, not stated out loud at the time (should have been — this case entry
is that admission). `lib/profiles.sh`/`lib/secrets.sh`/`lib/clients.sh` are
defined: we own the shape of a profile and a client config entry. The OAuth
surface against `mcp.webflow.com` was discovered: verified live (DCR
registration + full PKCE exchange) rather than assumed from Webflow's classic
Data API docs, which describe a different, client-secret-only flow.

## What broke

A test-org name collision overwrote a real client's entry in the user's real
Claude Desktop config during manual testing of `rename` — recovered from the
tool's own automatic `.bak`, no data lost. Full account in `friction.md`,
folded in below.

## Blocks adopted / rejected

- **Adopted:** OS keychain via `security`/`secret-tool`, with a `chmod 600`
  file fallback only when no keychain backend exists.
- **Adopted, then replaced:** a hand-rolled PKCE + refresh + local-callback
  OAuth flow, built and verified working, then thrown away for `mcp-remote`
  (github.com/punkpeye/mcp-remote) once it was clear that package already
  solves exactly this and is what the MCP ecosystem uses. What we kept
  owning: per-org isolation via `MCP_REMOTE_CONFIG_DIR`.
- **Rejected:** a manual OAuth-App-setup step (client_id/secret the user
  creates by hand before `connect` works) — assumed necessary, disproven by
  reading `mcp.webflow.com`'s own `.well-known/oauth-authorization-server`.

## Agent-first checklist, applied to this build

- `--json` + automatic JSON on non-TTY stdout: done, across every command
  (read and write).
- No prompt blocks a non-interactive run: `secret-set`/`rotate` refuse
  outright without a real TTY rather than hanging.
- `schema` command with a version field: added (`commands/schema.sh`,
  `schema_version: 1`).
- Exit codes: 0 success, 1 for both user error and failed check — not yet
  split further; revisit if a caller needs to distinguish "org not found"
  from "network unreachable" programmatically rather than reading `.error`.
- Data on stdout, diagnostics on stderr: yes — `wfw_say_err/warn/hint` all
  write to stderr, JSON payloads always to stdout.
- Secrets never echo, never accept as an argument: enforced at the CLI
  surface (`secret-set`/`rotate` read via `read -s`, no org's token is ever
  interpolated into a printed string).
- Trust ladder: sized to the actual damage. `install`/`remove`/`rename`
  mutate real, shared, global client config files (Claude Code/Desktop/
  Cursor) — that is the one place in this CLI where a wrong call has a real
  blast radius (see "what broke" above), so those three now have `--dry-run`
  and `remove` requires `--yes` with no interactive fallback. `add`/`connect`/
  `list`/`inspect`/`test`/`debug` earn no gate: worst case is a wasted API
  call or a duplicate profile you can `remove`.
- Audit log: append-only, `~/.flowmcp/audit/<YYYY-MM>.jsonl`,
  written after the action completes (not two-phase pending/final) since
  none of the mutating commands here are async or long-running enough for a
  killed-mid-flight state to matter the way it would for a payment API.
- `nextSteps`: added to `inspect`/`test`/`debug`/`install`/`remove`/`rename`
  JSON output as `next_steps: [string]`.

## What I'd do differently

Open `friction.md` on day one instead of reconstructing it after the fact.
The rename/real-org collision is exactly the kind of finding the skill says
gets rediscovered when nobody writes it down at the time — this build
rediscovered a version of it we'd already have known to avoid if a prior
case existed.
