# Contributing to flowmcp

Thanks for helping improve flowmcp.

## Layout

```
bin/flowmcp   dispatcher — resolves symlinks, sources lib/bootstrap.sh, routes to commands/
lib/                     shared functions: paths, secrets, profiles, client-config merge, audit log, UI
commands/                one script per verb, self-bootstrapping (works sourced or run standalone)
```

Every `commands/*.sh` starts with the same line so it works whether it's
`source`d by the dispatcher or shelled out to directly (e.g. `debug.sh`
calling `test.sh`):

```bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"
```

## The one hard rule

**No command may accept a token as a CLI argument or print one, ever.**
`secret-set`/`rotate` are the only commands that touch a token, and both
refuse to run without a real interactive TTY (`read -s`, hidden input). If a
change makes a token cross that boundary — as a function argument that isn't
a `local`/`nameref` passed by name, in a log line, in an error message — it
doesn't get merged, no exceptions.

## Development

Requires `bash`, `jq`, `curl`, and Node/`npx`.

```bash
npm link          # or: ln -s "$(pwd)/bin/flowmcp" /usr/local/bin/flowmcp
flowmcp --help
```

Link it globally before calling anything done — running `bash bin/flowmcp`
directly skips the symlink-resolution path (`bin/flowmcp`'s
`while [ -h "$SOURCE" ]` loop) and the `bin` field a real install goes
through, so it verifies less than it looks like it does.

## Testing changes

There is no test suite yet — verification is manual, against an isolated
environment:

```bash
export WFW_HOME=/tmp/wfw-test-$$
export HOME=/tmp/wfw-test-home-$$
mkdir -p "$HOME"
flowmcp add zzz-test-1 --label "Test Co"
# ... exercise the command you changed ...
rm -rf "$WFW_HOME" "$HOME"
```

**Always use an obviously-fake org name (`zzz-test-*`), never a name that
might collide with a real client.** `install`/`remove`/`rename` resolve
client config paths through the real `$HOME` by design (see
`lib/clients.sh:wfw_client_config_path`) unless `HOME` is overridden as
above — a name collision with a real org can silently repoint or delete a
real entry in someone's real Claude Code/Desktop/Cursor config. See
`friction.md` for the incident that made this rule non-optional.

Before opening a PR, run every changed `commands/*.sh` through `bash -n` at
minimum, and exercise the `--json` and (for `install`/`remove`/`rename`)
`--dry-run` paths, not just the human-output path — they're separate code
paths in every command that has them.

## Adding a command

1. Add `commands/<verb>.sh`, self-bootstrapping as above.
2. Add it to the whitelist `case` in `bin/flowmcp` and to
   `usage()`.
3. Add it to `commands/schema.sh` — usage, whether it mutates, whether it
   requires a TTY, whether it's destructive, and its JSON output shape.
   `schema` is how an agent discovers the surface without parsing
   `--help`; a command missing from it is invisible to that path.
4. If it prints structured output, include `next_steps: [string]` when
   there's an obvious follow-up command — that's the convention every other
   command's JSON output follows.
5. If it's read-only, no gate is needed. If it mutates a client config file
   or a stored secret, give it `--dry-run`; if it's irreversible without a
   backup, require an explicit `--yes` with no non-interactive default.

## Fold friction back in

If something in this doc, or an existing pattern in the code, turns out
wrong for a case you're working, write it down in `friction.md` before you
move past it. It's what keeps this file honest.

## License

MIT — contributions are accepted under the same license as the project.
