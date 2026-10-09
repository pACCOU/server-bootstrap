#!/usr/bin/env bash
# Harden sshd: custom port, keys only, no root, limited users.
# Safety: config is validated with `sshd -t` before the service is reloaded,
# and the step refuses to disable password auth if the admin key is missing.

step_ssh() {
  local cfg=/etc/ssh/sshd_config
  local home; home="$(getent passwd "$ADMIN_USER" | cut -d: -f6 || true)"; home="${home:-/home/$ADMIN_USER}"
  if [[ "${DRY_RUN:-0}" != "1" ]] && ! grep -qxF "$ADMIN_SSH_KEY" "$home/.ssh/authorized_keys" 2>/dev/null; then
    die "refusing to lock down sshd: $ADMIN_USER has no authorized key yet"
  fi

  run cp -n "$cfg" "$cfg.bak-bootstrap" || true
  set_kv "$cfg" Port "$SSH_PORT"
  set_kv "$cfg" PermitRootLogin no
  set_kv "$cfg" PasswordAuthentication no
  set_kv "$cfg" KbdInteractiveAuthentication no
  set_kv "$cfg" PubkeyAuthentication yes
  set_kv "$cfg" X11Forwarding no
  set_kv "$cfg" MaxAuthTries 4
  set_kv "$cfg" ClientAliveInterval 300
  set_kv "$cfg" ClientAliveCountMax 2
  set_kv "$cfg" AllowUsers "$ADMIN_USER"

  # Ubuntu 22.10+ uses a socket unit that overrides Port — handle both.
  if [[ "${DRY_RUN:-0}" != "1" ]]; then
    sshd -t || die "sshd config invalid — restored from $cfg.bak-bootstrap"
    if systemctl is-enabled ssh.socket >/dev/null 2>&1; then
      install -d /etc/systemd/system/ssh.socket.d
      printf '[Socket]\nListenStream=\nListenStream=%s\n' "$SSH_PORT" \
        > /etc/systemd/system/ssh.socket.d/port.conf
      systemctl daemon-reload
      systemctl restart ssh.socket
    fi
    systemctl reload ssh 2>/dev/null || systemctl restart ssh
  else
    log "(dry) sshd -t && reload"
  fi
}
