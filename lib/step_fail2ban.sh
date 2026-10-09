#!/usr/bin/env bash
# fail2ban with an sshd jail on the custom port and a recidive jail.

step_fail2ban() {
  local jail=/etc/fail2ban/jail.d/bootstrap.local
  if [[ "${DRY_RUN:-0}" == "1" ]]; then log "(dry) write $jail"; else
    cat > "$jail" <<EOF
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
backend  = systemd

[sshd]
enabled = true
port    = ${SSH_PORT}
mode    = aggressive

[recidive]
enabled  = true
bantime  = 1w
findtime = 1d
maxretry = 3
EOF
  fi
  run systemctl enable --now fail2ban
  run systemctl restart fail2ban
}
