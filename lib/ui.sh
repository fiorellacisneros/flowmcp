#!/usr/bin/env bash
# Terminal output helpers: colors auto-disable when not a real TTY, when
# NO_COLOR is set, or when TERM=dumb — so agent tool-call output and piped
# logs stay plain text, never raw ANSI escapes.

if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]; then
  WFW_C_RESET=$'\033[0m'
  WFW_C_BOLD=$'\033[1m'
  WFW_C_DIM=$'\033[2m'
  WFW_C_GREEN=$'\033[32m'
  WFW_C_RED=$'\033[31m'
  WFW_C_GRAY=$'\033[90m'
  # forhuman palette — used for all CLI chrome (banner accents, next/hint labels).
  WFW_C_YELLOW=$'\033[38;2;255;190;0m'    # forhuman yellow #FFBE00 — hint/warn
  WFW_C_CYAN=$'\033[38;2;1;46;220m'       # forhuman blue #012EDC — next / accents
  # Webflow's own brand blue, used ONLY for the Webflow "W" logo glyph —
  # deliberately kept true to Webflow's real color, not the forhuman palette.
  WFW_C_BRAND=$'\033[38;2;45;113;236m'    # Webflow blue #2D71EC
  WFW_C_BRAND_DIM=$'\033[38;2;22;56;118m' # dimmed brand blue, for the "breathing" idle frame
else
  WFW_C_RESET="" WFW_C_BOLD="" WFW_C_DIM="" WFW_C_GREEN="" WFW_C_RED="" WFW_C_YELLOW="" WFW_C_CYAN="" WFW_C_GRAY="" WFW_C_BRAND="" WFW_C_BRAND_DIM=""
fi

# Webflow "W" mark, rasterized from the brand SVG into half-block glyphs
# (▀▄█) so it renders in any terminal — no image protocol dependency.
WFW_LOGO_LINES=(
  '████████████     ██████████    ▄█████████████'
  '████████████    ███████████   ▄█████████████'
  '████████████   ████████████  ▄█████████████'
  '████████████  █████████████ ▄█████████████'
  '████████████ ██████████████▄█████████████'
  '████████████████████████████████████████'
  '         ▄█████████████████████████████'
  '      ▄▄██████████████████████████████'
  '▄▄▄██████████████████████████████████'
  '█████████████████████▀▄█████████████'
  '███████████████████▀ ▄█████████████'
  '████████████████▀▀  ▄█████████████'
  '█████████████▀▀    ▄█████████████'
  '████████▀▀        ▄█████████████'
)

# wfw_logo [color] — prints the Webflow "W" mark in the given color
# (defaults to brand blue). Prints nothing when colors are disabled — the
# glyph reads as noise without color, so callers should have a plain-text
# fallback for non-TTY/NO_COLOR contexts.
wfw_logo() {
  local color="${1:-$WFW_C_BRAND}"
  [[ -z "$WFW_C_RESET" ]] && return 0
  local line
  for line in "${WFW_LOGO_LINES[@]}"; do
    printf "%s%s%s\n" "$color" "$line" "$WFW_C_RESET"
  done
}

wfw_say_ok()   { echo "${WFW_C_GREEN}ok${WFW_C_RESET}      $*"; }
wfw_say_err()  { echo "${WFW_C_RED}error${WFW_C_RESET}   $*" >&2; }
wfw_say_warn() { echo "${WFW_C_YELLOW}warn${WFW_C_RESET}    $*" >&2; }
wfw_say_hint() { echo "${WFW_C_YELLOW}hint${WFW_C_RESET}    $*" >&2; }
wfw_say_next() { echo "${WFW_C_CYAN}next${WFW_C_RESET}    $*"; }

# wfw_status_color <word> -> colorizes ok/pass/available/available green,
# fail/error/taken red, anything else (e.g. "never") dim gray.
wfw_status_color() {
  local s="$1"
  case "$s" in
    ok|pass|available) echo "${WFW_C_GREEN}${s}${WFW_C_RESET}" ;;
    fail|error|taken)  echo "${WFW_C_RED}${s}${WFW_C_RESET}" ;;
    *)                 echo "${WFW_C_GRAY}${s}${WFW_C_RESET}" ;;
  esac
}

# wfw_status_color_padded <status> <width> — colorize, then pad on VISIBLE
# length (not the ANSI-code length) so table columns stay aligned.
wfw_status_color_padded() {
  local s="$1"
  local width="$2"
  local pad=$(( width - ${#s} ))
  (( pad < 0 )) && pad=0
  printf "%s%s" "$(wfw_status_color "$s")" "$(printf "%${pad}s" "")"
}

wfw_version() {
  local pkg="$WFW_LIB_DIR/../package.json"
  if [[ -f "$pkg" ]]; then
    jq -r '.version' "$pkg" 2>/dev/null || echo "0.0.0-dev"
  else
    echo "0.0.0-dev"
  fi
}

# wfw_wait_with_logo <background-pid> — redraws the logo, alternating
# brand/dim color for a "breathing" effect, until the given background job
# exits. No-op (prints nothing) when colors are disabled — caller should
# print its own plain-text waiting message before calling this.
wfw_wait_with_logo() {
  local pid="$1" n="${#WFW_LOGO_LINES[@]}" frame=0 status=0
  if [[ -z "$WFW_C_RESET" ]]; then
    if wait "$pid"; then status=0; else status=$?; fi
    return $status
  fi
  while kill -0 "$pid" 2>/dev/null; do
    if (( frame % 2 == 0 )); then wfw_logo "$WFW_C_BRAND"; else wfw_logo "$WFW_C_BRAND_DIM"; fi
    frame=$(( frame + 1 ))
    sleep 0.6
    printf "\033[%dA" "$n"
  done
  if wait "$pid"; then status=0; else status=$?; fi
  printf "\033[0J"  # clear from cursor to end of screen (removes last logo frame)
  return $status
}

wfw_banner() {
  if [[ -n "$WFW_C_RESET" ]]; then
    wfw_logo
    echo "${WFW_C_BOLD}flowmcp${WFW_C_RESET}  ${WFW_C_DIM}v$(wfw_version)${WFW_C_RESET}  ${WFW_C_YELLOW}·${WFW_C_RESET} ${WFW_C_CYAN}by forhuman${WFW_C_RESET}"
  else
    echo "flowmcp v$(wfw_version) · by forhuman"
  fi
  echo "${WFW_C_DIM}$(wfw_t tagline)${WFW_C_RESET}"
}
