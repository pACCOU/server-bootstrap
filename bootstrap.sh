#!/usr/bin/env bash
# =============================================================================
#  server-bootstrap — turn a fresh Ubuntu 22.04 / 24.04 VPS into a hardened,
#  monitored host ready to run Docker workloads behind Nginx + Let's Encrypt.
#
#  Usage:   sudo ./bootstrap.sh -c bootstrap.conf [--dry-run] [--only step,…]
#  Steps:   system, user, ssh, firewall, fail2ban, docker, nginx, backup, audit
#
#  Idempotent: every step checks before it changes, so re-running is safe.
#  Each step logs to /var/log/server-bootstrap.log and the final "audit"
#  step prints a pass/fail checklist you can paste into a handover note.
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

CONF=""
DRY_RUN=0
ONLY=""

usage() {
  sed -n '2,13p' "$0" | sed 's/^# \{0,2\}//'
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--config) CONF="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --only)      ONLY="$2"; shift 2 ;;
    -h|--help)   usage ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n "$CONF" ]] || usage
[[ -r "$CONF" ]] || die "config not readable: $CONF"
# shellcheck source=bootstrap.conf.example
source "$CONF"
require_vars ADMIN_USER ADMIN_SSH_KEY SSH_PORT TIMEZONE
[[ $EUID -eq 0 ]] || die "run as root (sudo)"

export DRY_RUN

STEPS=(system user ssh firewall fail2ban docker nginx backup audit)
if [[ -n "$ONLY" ]]; then IFS=',' read -r -a STEPS <<< "$ONLY"; fi

for step in "${STEPS[@]}"; do
  f="$SCRIPT_DIR/lib/step_${step}.sh"
  [[ -r "$f" ]] || die "no such step: $step"
  log "===== step: $step ====="
  # shellcheck disable=SC1090
  source "$f"
  "step_${step}"
done

log "done. Summary written to /var/log/server-bootstrap.log"
