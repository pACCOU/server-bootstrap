#!/usr/bin/env bash
# UFW: deny inbound by default, allow SSH (custom port) + HTTP/HTTPS.
# Extra ports come from EXTRA_TCP_PORTS="8080 9000" in the config.

step_firewall() {
  run ufw --force reset >/dev/null
  run ufw default deny incoming
  run ufw default allow outgoing
  run ufw limit "${SSH_PORT}/tcp" comment 'ssh (rate limited)'
  run ufw allow 80/tcp  comment 'http'
  run ufw allow 443/tcp comment 'https'
  for p in ${EXTRA_TCP_PORTS:-}; do run ufw allow "${p}/tcp"; done
  run ufw --force enable
  run ufw status verbose
}
