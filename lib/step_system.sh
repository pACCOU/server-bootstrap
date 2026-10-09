#!/usr/bin/env bash
# Updates, timezone, unattended security upgrades, basic tooling.

step_system() {
  run env DEBIAN_FRONTEND=noninteractive apt-get update -q
  run env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -q
  apt_install curl ca-certificates gnupg lsb-release ufw fail2ban \
              unattended-upgrades apt-listchanges htop ncdu rsync logrotate

  if [[ "$(timedatectl show -p Timezone --value 2>/dev/null)" != "$TIMEZONE" ]]; then
    run timedatectl set-timezone "$TIMEZONE"
  fi

  # Automatic security updates only (never feature upgrades)
  local au=/etc/apt/apt.conf.d/20auto-upgrades
  set_kv "$au" 'APT::Periodic::Update-Package-Lists' '"1";' ' '
  set_kv "$au" 'APT::Periodic::Unattended-Upgrade'    '"1";' ' '
  run systemctl enable --now unattended-upgrades

  # Sensible kernel hardening (sysctl)
  local sc=/etc/sysctl.d/60-hardening.conf
  set_kv "$sc" net.ipv4.conf.all.rp_filter 1 '='
  set_kv "$sc" net.ipv4.conf.all.accept_redirects 0 '='
  set_kv "$sc" net.ipv4.conf.all.send_redirects 0 '='
  set_kv "$sc" net.ipv4.tcp_syncookies 1 '='
  set_kv "$sc" kernel.kptr_restrict 2 '='
  run sysctl --system >/dev/null
}
