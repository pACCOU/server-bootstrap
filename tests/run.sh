#!/usr/bin/env bash
# CI-friendly checks: static analysis + a dry run with a throwaway config.
set -Eeuo pipefail
cd "$(dirname "$0")/.."

echo "== bash -n (syntax)"
for f in bootstrap.sh lib/*.sh; do bash -n "$f"; done

if command -v shellcheck >/dev/null 2>&1; then
  echo "== shellcheck"
  shellcheck -x bootstrap.sh lib/*.sh
else
  echo "== shellcheck not installed, skipped"
fi

echo "== dry run"
tmp=$(mktemp -d)
cat > "$tmp/conf" <<'EOF'
ADMIN_USER="deploy"
ADMIN_SSH_KEY="ssh-ed25519 AAAATESTKEY test@ci"
SSH_PORT="2222"
TIMEZONE="UTC"
DOMAIN="app.example.test"
LETSENCRYPT_EMAIL="ops@example.test"
EOF
# dry-run must not need root for the pure-planning steps
LOG_FILE="$tmp/log" DRY_RUN=1 bash -c '
  source lib/common.sh
  source "'"$tmp"'/conf"
  for s in system user ssh firewall fail2ban docker nginx backup; do
    source "lib/step_$s.sh"; "step_$s" >/dev/null
  done
' 2>"$tmp/stderr" && echo "dry run OK ($(grep -c DRY "$tmp/stderr") planned commands)"
rm -rf "$tmp"
echo "all checks passed"
