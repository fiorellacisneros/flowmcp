#!/usr/bin/env bash
# Secret storage backend abstraction: OS keychain first, chmod-600 file fallback.
#
# SECURITY CONTRACT — read before touching this file:
#   - secret_get MUST NEVER be called anywhere that prints its output to a
#     terminal an agent can read back (no `echo "$(secret_get ...)"`,
#     no command substitution that lands in a variable that later gets
#     echoed/logged, no `set -x` in a scope that calls it).
#   - The only two legitimate callers of secret_get are commands/test.sh
#     and commands/run-mcp.sh, and both must consume the value directly
#     into a curl header or an exported env var for a child process —
#     never print it.
#   - secret_set MUST NEVER accept the token as a CLI argument (visible in
#     `ps`, shell history, and any agent tool-call transcript). It only
#     reads from a variable already held in the calling shell (which itself
#     must have come from an interactive `read -s`, never from an argv).
#   - Windows (dpapi-file backend): the token is piped to powershell.exe via
#     stdin only, never interpolated into the -Command script text itself —
#     the script text contains no secret material, so it stays safe to have
#     visible in a process listing the same way any other command is.

wfw_secret_backend() {
  if [[ "$(uname -s)" == "Darwin" ]] && command -v security >/dev/null 2>&1; then
    echo "keychain-macos"
  elif command -v secret-tool >/dev/null 2>&1; then
    echo "keychain-linux"
  elif [[ "$(wfw_os)" == "windows" ]] && command -v powershell.exe >/dev/null 2>&1; then
    echo "dpapi-file"
  else
    echo "file"
  fi
}

# secret_set <org> <token-var-name>
# Pass the *name* of the variable holding the token, not the token itself,
# so this function can unset it from the caller's scope when done.
wfw_secret_set() {
  local org="$1" varname="$2" backend
  backend="$(wfw_secret_backend)"
  local token="${!varname}"
  case "$backend" in
    keychain-macos)
      security add-generic-password -a "$org" -s "$WFW_KEYCHAIN_SERVICE" -w "$token" -U >/dev/null
      ;;
    keychain-linux)
      printf '%s' "$token" | secret-tool store --label="Webflow token ($org)" \
        service "$WFW_KEYCHAIN_SERVICE" account "$org"
      ;;
    dpapi-file)
      local f
      f="$(wfw_to_posix_path "$WFW_SECRETS_DIR")/$org.dpapi"
      umask 077
      # Token only ever travels via stdin, never argv or an interpolated
      # -Command string — PowerShell reads it, encrypts it, and writes the
      # file itself so the plaintext never lands anywhere else on disk.
      export WFW_SECRET_FILE
      WFW_SECRET_FILE="$(cygpath -w "$f" 2>/dev/null || echo "$f")"
      printf '%s' "$token" | powershell.exe -NoProfile -NonInteractive -Command '
        $ErrorActionPreference = "Stop"
        Add-Type -AssemblyName System.Security
        $plain = [Console]::In.ReadToEnd()
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($plain)
        $protected = [System.Security.Cryptography.ProtectedData]::Protect(
          $bytes, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        [Convert]::ToBase64String($protected) | Set-Content -NoNewline -Path $env:WFW_SECRET_FILE
      '
      unset WFW_SECRET_FILE
      chmod 600 "$f" 2>/dev/null || true
      ;;
    file)
      local f="$WFW_SECRETS_DIR/$org.token"
      umask 077
      printf '%s' "$token" > "$f"
      chmod 600 "$f"
      ;;
  esac
  unset -v "$varname"
}

# secret_get <org> -> prints token to stdout. Callers must capture, not print.
wfw_secret_get() {
  local org="$1" backend
  backend="$(wfw_secret_backend)"
  case "$backend" in
    keychain-macos)
      security find-generic-password -a "$org" -s "$WFW_KEYCHAIN_SERVICE" -w 2>/dev/null
      ;;
    keychain-linux)
      secret-tool lookup service "$WFW_KEYCHAIN_SERVICE" account "$org" 2>/dev/null
      ;;
    dpapi-file)
      local f
      f="$(wfw_to_posix_path "$WFW_SECRETS_DIR")/$org.dpapi"
      [[ -f "$f" ]] || return 0
      export WFW_SECRET_FILE
      WFW_SECRET_FILE="$(cygpath -w "$f" 2>/dev/null || echo "$f")"
      powershell.exe -NoProfile -NonInteractive -Command '
        $ErrorActionPreference = "Stop"
        Add-Type -AssemblyName System.Security
        $b64 = Get-Content -Raw -Path $env:WFW_SECRET_FILE
        $protected = [Convert]::FromBase64String($b64)
        $bytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
          $protected, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        [Console]::Out.Write([System.Text.Encoding]::UTF8.GetString($bytes))
      ' 2>/dev/null
      unset WFW_SECRET_FILE
      ;;
    file)
      cat "$WFW_SECRETS_DIR/$org.token" 2>/dev/null
      ;;
  esac
}

wfw_secret_exists() {
  local org="$1"
  [[ -n "$(wfw_secret_get "$org" || true)" ]]
}

wfw_secret_delete() {
  local org="$1" backend
  backend="$(wfw_secret_backend)"
  case "$backend" in
    keychain-macos)
      security delete-generic-password -a "$org" -s "$WFW_KEYCHAIN_SERVICE" >/dev/null 2>&1 || true
      ;;
    keychain-linux)
      secret-tool clear service "$WFW_KEYCHAIN_SERVICE" account "$org" >/dev/null 2>&1 || true
      ;;
    dpapi-file)
      rm -f "$(wfw_to_posix_path "$WFW_SECRETS_DIR")/$org.dpapi"
      ;;
    file)
      rm -f "$WFW_SECRETS_DIR/$org.token"
      ;;
  esac
}
