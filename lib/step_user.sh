#!/usr/bin/env bash
# Non-root admin user with sudo and the provided SSH public key.

step_user() {
  if ! id "$ADMIN_USER" >/dev/null 2>&1; then
    run useradd -m -s /bin/bash -G sudo "$ADMIN_USER"
    run passwd -l "$ADMIN_USER"          # key-only login; sudo via NOPASSWD below
  else
    log "user $ADMIN_USER exists"
  fi

  local home; home="$(getent passwd "$ADMIN_USER" | cut -d: -f6 || true)"; home="${home:-/home/$ADMIN_USER}"
  run install -d -m 700 -o "$ADMIN_USER" -g "$ADMIN_USER" "$home/.ssh"
  local ak="$home/.ssh/authorized_keys"
  if ! grep -qxF "$ADMIN_SSH_KEY" "$ak" 2>/dev/null; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then log "(dry) add key to $ak"; else
      printf '%s\n' "$ADMIN_SSH_KEY" >> "$ak"
    fi
  fi
  run chmod 600 "$ak"; run chown "$ADMIN_USER:$ADMIN_USER" "$ak"

  local sudoers=/etc/sudoers.d/90-$ADMIN_USER
  if [[ ! -f "$sudoers" ]]; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then log "(dry) write $sudoers"; else
      printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$ADMIN_USER" > "$sudoers"
      chmod 440 "$sudoers"
      visudo -cf "$sudoers" >/dev/null || die "sudoers syntax error"
    fi
  fi
}
