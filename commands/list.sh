#!/usr/bin/env bash
# Usage: flowmcp list [--json] [--fast]
# Lists registered orgs with whether each one actually works RIGHT NOW —
# asked of Webflow itself, not inferred from a file or from the last test —
# and the clients each one is installed in. --fast skips the Webflow check
# and only reports whether a login is saved locally. Never prints tokens.
# JSON automatically when stdout isn't a real TTY (e.g. an agent's tool call).

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/bootstrap.sh"

json_flag=""
fast=""
for arg in "$@"; do
  case "$arg" in
    --json) json_flag="1" ;;
    --fast) fast="1" ;;
    *) echo "error: unknown option '$arg'" >&2; exit 1 ;;
  esac
done

orgs=($(wfw_profile_list))

if [[ ${#orgs[@]} -eq 0 ]]; then
  if wfw_json_mode "$json_flag"; then echo "[]"; else wfw_t msg_no_orgs; fi
  exit 0
fi

# states: working | expired | failed | no_session | no_response | saved
states=()
auths=()
probe_dir="$(mktemp -d)"
trap 'rm -rf "$probe_dir"' EXIT

i=0
for org in "${orgs[@]}"; do
  p="$(wfw_profile_read "$org")"
  auths[$i]="$(jq -r '.auth_method // "pat"' <<<"$p")"
  if ! wfw_org_has_session "$org" "${auths[$i]}"; then
    states[$i]="no_session"
  elif [[ -n "$fast" ]]; then
    states[$i]="saved"
  elif [[ "${auths[$i]}" == "mcp-remote" ]]; then
    case "$(wfw_os)" in
      macos|linux)
        node "$WFW_LIB_DIR/probe-mcp-remote.js" "$(wfw_mcp_remote_dir "$org")" \
          "$WFW_MCP_REMOTE_VERSION" "$WFW_MCP_URL" >"$probe_dir/$org" 2>/dev/null &
        states[$i]="probing"
        ;;
      *) states[$i]="saved" ;;
    esac
  else
    "$WFW_COMMANDS_DIR/test.sh" "$org" --json >"$probe_dir/$org" 2>/dev/null &
    states[$i]="probing"
  fi
  i=$(( i + 1 ))
done

if [[ " ${states[*]} " == *" probing "* ]]; then
  if ! wfw_json_mode "$json_flag" && [[ -t 2 ]]; then
    wfw_t list_checking "${#orgs[@]}" >&2
  fi
  wait
fi

for (( i = 0; i < ${#orgs[@]}; i++ )); do
  [[ "${states[i]}" == "probing" ]] || continue
  org="${orgs[i]}"
  res="$(cat "$probe_dir/$org" 2>/dev/null || true)"
  result="$(jq -r '.status // empty' <<<"$res" 2>/dev/null || true)"
  if [[ "${auths[i]}" == "mcp-remote" ]]; then
    case "$result" in
      ok)
        states[$i]="working"
        wfw_profile_update_last_test "$org" "ok" "[]" "null" ""
        ;;
      needs_login)
        states[$i]="expired"
        wfw_profile_update_last_test "$org" "fail" "[]" "null" "saved session no longer accepted by Webflow"
        ;;
      *) states[$i]="no_response" ;;
    esac
  else
    if [[ "$result" == "ok" ]]; then states[$i]="working"; else states[$i]="failed"; fi
  fi
done

if wfw_json_mode "$json_flag"; then
  for (( i = 0; i < ${#orgs[@]}; i++ )); do
    org="${orgs[i]}"
    if [[ "${states[i]}" == "no_session" ]]; then has=false; else has=true; fi
    installed="$(wfw_org_installed_in "$org" | jq -R . | jq -sc .)"
    wfw_profile_read "$org" | jq -c --arg status "${states[i]}" --argjson session "$has" \
      --argjson installed_in "$installed" '. + {status: $status, session: $session, installed_in: $installed_in}'
  done | jq -sc '.'
  exit 0
fi

# Colored text padded on VISIBLE width. The table words are ASCII on purpose,
# so ${#text} is the real on-screen width even under a non-UTF-8 locale.
pad_color() {
  local color="$1" text="$2" width="$3" pad
  pad=$(( width - ${#text} ))
  if (( pad < 0 )); then pad=0; fi
  printf '%s%s%s%*s' "$color" "$text" "$WFW_C_RESET" "$pad" ""
}

h_status="$(wfw_t list_col_status)"
h_inst="$(wfw_t list_col_installed)"
txt_working="$(wfw_t list_state_working)"
txt_broken="$(wfw_t list_state_broken)"
txt_none="$(wfw_t list_state_none)"
txt_noresp="$(wfw_t list_state_noresp)"
txt_saved="$(wfw_t list_state_saved)"

w_org=3
w_status=${#h_status}
for t in "$txt_working" "$txt_broken" "$txt_none" "$txt_noresp" "$txt_saved"; do
  if (( ${#t} > w_status )); then w_status=${#t}; fi
done
w_inst=${#h_inst}

installs=()
broken=()
noresp=()
multi=()

for (( i = 0; i < ${#orgs[@]}; i++ )); do
  org="${orgs[i]}"

  inst_text=""
  distinct=""
  ndistinct=0
  ents="$(wfw_org_installed_in "$org")"
  while IFS= read -r ent; do
    [[ -n "$ent" ]] || continue
    client="${ent%%:*}"
    scope="${ent##*:}"
    disp="$client"
    if [[ "$scope" == "project" ]]; then disp="$client:project"; fi
    inst_text="${inst_text:+$inst_text, }$disp"
    case ",$distinct," in
      *",$client,"*) ;;
      *) distinct="${distinct:+$distinct,}$client"; ndistinct=$(( ndistinct + 1 )) ;;
    esac
  done <<<"$ents"
  if [[ -z "$inst_text" ]]; then inst_text="$(wfw_t list_not_installed)"; fi
  if (( ndistinct > 1 )); then multi+=("$org|${distinct//,/, }"); fi
  installs[$i]="$inst_text"

  case "${states[i]}" in
    expired|failed|no_session) broken+=("$org") ;;
    no_response) noresp+=("$org") ;;
  esac

  if (( ${#org} > w_org )); then w_org=${#org}; fi
  if (( ${#inst_text} > w_inst )); then w_inst=${#inst_text}; fi
done

printf "${WFW_C_DIM}%-*s  %-*s  %s${WFW_C_RESET}\n" "$w_org" "ORG" "$w_status" "$h_status" "$h_inst"

for (( i = 0; i < ${#orgs[@]}; i++ )); do
  case "${states[i]}" in
    working)     cell="$(pad_color "$WFW_C_GREEN" "$txt_working" "$w_status")" ;;
    expired|failed) cell="$(pad_color "$WFW_C_RED" "$txt_broken" "$w_status")" ;;
    no_session)  cell="$(pad_color "$WFW_C_RED" "$txt_none" "$w_status")" ;;
    no_response) cell="$(pad_color "$WFW_C_YELLOW" "$txt_noresp" "$w_status")" ;;
    *)           cell="$(pad_color "$WFW_C_GRAY" "$txt_saved" "$w_status")" ;;
  esac
  printf "%-*s  %s  %s\n" "$w_org" "${orgs[i]}" "$cell" "${installs[i]}"
done

if (( ${#broken[@]} > 0 )); then
  echo
  wfw_say_warn "$(wfw_t list_warn_broken "$(IFS=,; echo "${broken[*]}" | sed 's/,/, /g')")"
fi
if (( ${#noresp[@]} > 0 )); then
  wfw_say_warn "$(wfw_t list_warn_noresp "$(IFS=,; echo "${noresp[*]}" | sed 's/,/, /g')")"
fi
if (( ${#multi[@]} > 0 )); then
  for entry in "${multi[@]}"; do
    wfw_say_warn "$(wfw_t list_warn_multi "${entry%%|*}" "${entry#*|}")"
  done
fi
