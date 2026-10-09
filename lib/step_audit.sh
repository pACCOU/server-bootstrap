#!/usr/bin/env bash
# Prints a PASS/FAIL checklist. Exit status is non-zero if anything failed,
# so you can run `bootstrap.sh --only audit` from monitoring.

step_audit() {
  local fails=0
  echo
  echo "Hardening audit — $(hostname) — $(date '+%F %T')"
  check "root login disabled"            sh -c "sshd -T 2>/dev/null | grep -q '^permitrootlogin no'"            || ((fails++))
  check "password auth disabled"         sh -c "sshd -T 2>/dev/null | grep -q '^passwordauthentication no'"     || ((fails++))
  check "sshd on port $SSH_PORT"         sh -c "sshd -T 2>/dev/null | grep -q '^port $SSH_PORT'"               || ((fails++))
  check "admin user $ADMIN_USER exists"  id "$ADMIN_USER"                                                      || ((fails++))
  check "ufw active"                     sh -c "ufw status | grep -q 'Status: active'"                         || ((fails++))
  check "fail2ban running"               systemctl is-active fail2ban                                          || ((fails++))
  check "unattended-upgrades enabled"    systemctl is-enabled unattended-upgrades                              || ((fails++))
  check "docker running"                 systemctl is-active docker                                            || ((fails++))
  check "backup timer enabled"           systemctl is-enabled nightly-backup.timer                             || ((fails++))
  if [[ -n "${DOMAIN:-}" ]]; then
    check "nginx running"                systemctl is-active nginx                                             || ((fails++))
    check "TLS cert present for $DOMAIN" test -s "/etc/letsencrypt/live/$DOMAIN/fullchain.pem"               || ((fails++))
  fi
  echo
  if [[ $fails -eq 0 ]]; then log "audit: all checks passed"; else warn "audit: $fails check(s) failed"; fi
  return $fails
}
