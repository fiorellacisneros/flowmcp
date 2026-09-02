#!/usr/bin/env bash
# Usage: flowmcp lang [en|es] [--json]
# With no argument, prints the current language. With en/es, sets it —
# this is how a human changes the choice made at first run (or an agent
# sets it on their behalf; unlike secret-set/rotate, no token is involved
# here, so there's no reason to gate this behind a TTY).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

json_flag=""
new_lang=""
for arg in "$@"; do
  case "$arg" in
    --json) json_flag="1" ;;
    en|es)  new_lang="$arg" ;;
    *)
      echo "error: unknown language '$arg' (supported: en, es)" >&2
      exit 1
      ;;
  esac
done

if [[ -n "$new_lang" ]]; then
  echo "$new_lang" > "$WFW_LANG_FILE"
  if wfw_json_mode "$json_flag"; then
    jq -nc --arg lang "$new_lang" '{ok: true, lang: $lang}'
  else
    wfw_say_ok "language set to $new_lang"
  fi
  exit 0
fi

current="$(wfw_lang)"
if wfw_json_mode "$json_flag"; then
  jq -nc --arg lang "$current" '{lang: $lang}'
else
  echo "$current"
fi
