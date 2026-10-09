#!/usr/bin/env bash
# Shared helpers. Sourced by bootstrap.sh and every step.

LOG_FILE="${LOG_FILE:-/var/log/server-bootstrap.log}"

log()  { printf '%s [INFO ] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE" >&2; }
warn() { printf '%s [WARN ] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE" >&2; }
die()  { printf '%s [ERROR] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE" >&2; exit 1; }

# run <cmd…>: execute, or just print when DRY_RUN=1
run() {
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    printf '%s [DRY  ] %s\n' "$(date '+%F %T')" "$*" >&2
  else
    log "+ $*"
    "$@"
  fi
}

require_vars() {
  local missing=0
  for v in "$@"; do
    if [[ -z "${!v:-}" ]]; then warn "missing config variable: $v"; missing=1; fi
  done
  [[ $missing -eq 0 ]] || die "config incomplete"
}

pkg_installed() { dpkg -s "$1" >/dev/null 2>&1; }

apt_install() {
  local todo=()
  for p in "$@"; do pkg_installed "$p" || todo+=("$p"); done
  if [[ ${#todo[@]} -gt 0 ]]; then
    run env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${todo[@]}"
  else
    log "packages already present: $*"
  fi
}

# set_kv FILE KEY VALUE [SEP] — set "KEY VALUE" (sshd style) or "KEY=VALUE"
set_kv() {
  local file="$1" key="$2" value="$3" sep="${4:- }"
  if grep -qE "^\s*#?\s*${key}[[:space:]=]" "$file" 2>/dev/null; then
    run sed -i -E "s|^\s*#?\s*${key}[[:space:]=].*|${key}${sep}${value}|" "$file"
  else
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      printf '%s [DRY  ] append "%s%s%s" >> %s\n' "$(date '+%F %T')" "$key" "$sep" "$value" "$file" >&2
    else
      printf '%s%s%s\n' "$key" "$sep" "$value" >> "$file"
    fi
  fi
}

# check "label" cmd… — used by the audit step; prints PASS/FAIL, returns status
check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then
    printf '  [PASS] %s\n' "$label"; return 0
  else
    printf '  [FAIL] %s\n' "$label"; return 1
  fi
}
