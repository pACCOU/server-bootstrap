#!/usr/bin/env bash
# Nginx reverse proxy + Let's Encrypt certificate (certbot) for DOMAIN,
# proxying to UPSTREAM (default 127.0.0.1:8080). Skipped when DOMAIN is empty.

step_nginx() {
  if [[ -z "${DOMAIN:-}" ]]; then log "DOMAIN not set — skipping nginx/certbot"; return 0; fi
  apt_install nginx certbot python3-certbot-nginx
  local site=/etc/nginx/sites-available/"$DOMAIN"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then log "(dry) write $site"; else
    cat > "$site" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    # Security headers (certbot adds the TLS block)
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header Referrer-Policy strict-origin-when-cross-origin;

    client_max_body_size 25m;

    location / {
        proxy_pass         http://${UPSTREAM:-127.0.0.1:8080};
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_set_header   Upgrade           \$http_upgrade;
        proxy_set_header   Connection        "upgrade";
        proxy_read_timeout 120s;
    }
}
EOF
    ln -sf "$site" /etc/nginx/sites-enabled/"$DOMAIN"
    rm -f /etc/nginx/sites-enabled/default
    nginx -t || die "nginx config invalid"
  fi
  run systemctl enable --now nginx
  run systemctl reload nginx

  if [[ -n "${LETSENCRYPT_EMAIL:-}" ]]; then
    run certbot --nginx -d "$DOMAIN" -m "$LETSENCRYPT_EMAIL" --agree-tos --non-interactive --redirect
    run systemctl enable --now certbot.timer     # auto-renewal
  else
    warn "LETSENCRYPT_EMAIL not set — HTTP only, no certificate requested"
  fi
}
