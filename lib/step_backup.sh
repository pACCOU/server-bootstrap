#!/usr/bin/env bash
# Nightly backup of BACKUP_PATHS to BACKUP_DEST (local dir or rsync target),
# keeping BACKUP_KEEP_DAYS days. Installs /usr/local/bin/nightly-backup and a
# systemd timer (more observable than cron: `systemctl list-timers`).

step_backup() {
  local script=/usr/local/bin/nightly-backup
  if [[ "${DRY_RUN:-0}" == "1" ]]; then log "(dry) write $script + timer"; return 0; fi

  cat > "$script" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
STAMP=\$(date +%F)
DEST="${BACKUP_DEST:-/var/backups/nightly}"
KEEP=${BACKUP_KEEP_DAYS:-14}
mkdir -p "\$DEST"
tar -czf "\$DEST/backup-\$STAMP.tar.gz" ${BACKUP_PATHS:-/etc /home /var/www} 2>/dev/null || true
# any docker volumes
for v in \$(docker volume ls -q 2>/dev/null); do
  docker run --rm -v "\$v":/data:ro -v "\$DEST":/out alpine \\
    tar -czf "/out/volume-\$v-\$STAMP.tar.gz" -C /data . || echo "volume \$v failed" >&2
done
find "\$DEST" -name '*.tar.gz' -mtime +"\$KEEP" -delete
logger -t nightly-backup "backup \$STAMP done ($(du -sh "\$DEST" | cut -f1) total)"
EOF
  chmod 755 "$script"

  cat > /etc/systemd/system/nightly-backup.service <<EOF
[Unit]
Description=Nightly backup
[Service]
Type=oneshot
ExecStart=$script
EOF
  cat > /etc/systemd/system/nightly-backup.timer <<'EOF'
[Unit]
Description=Run nightly backup at 02:30
[Timer]
OnCalendar=*-*-* 02:30:00
RandomizedDelaySec=15m
Persistent=true
[Install]
WantedBy=timers.target
EOF
  systemctl daemon-reload
  systemctl enable --now nightly-backup.timer
}
