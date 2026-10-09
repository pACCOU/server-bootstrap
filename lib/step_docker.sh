#!/usr/bin/env bash
# Docker Engine + Compose plugin from Docker's official repository,
# log rotation for containers, admin user in the docker group.

step_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    run install -m 0755 -d /etc/apt/keyrings
    if [[ "${DRY_RUN:-0}" != "1" ]]; then
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu %s stable\n' \
        "$(dpkg --print-architecture)" "$(lsb_release -cs)" > /etc/apt/sources.list.d/docker.list
    fi
    run env DEBIAN_FRONTEND=noninteractive apt-get update -q
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    log "docker already installed: $(docker --version)"
  fi

  local dj=/etc/docker/daemon.json
  if [[ ! -f "$dj" ]]; then
    if [[ "${DRY_RUN:-0}" == "1" ]]; then log "(dry) write $dj"; else
      install -d /etc/docker
      cat > "$dj" <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "20m", "max-file": "5" },
  "live-restore": true
}
EOF
    fi
  fi
  run systemctl enable --now docker
  id -nG "$ADMIN_USER" | grep -qw docker || run usermod -aG docker "$ADMIN_USER"
}
