# server-bootstrap

One command to take a fresh **Ubuntu 22.04 / 24.04** VPS (DigitalOcean, Hetzner,
OVH, AWS Lightsail…) from "root password in an e-mail" to a hardened,
monitored host that is ready to run Docker workloads behind Nginx with a
Let's Encrypt certificate.

```bash
cp bootstrap.conf.example bootstrap.conf   # edit: your user, SSH key, domain
sudo ./bootstrap.sh -c bootstrap.conf --dry-run   # see what would change
sudo ./bootstrap.sh -c bootstrap.conf             # do it (≈ 3–5 min)
```

## What you get

| Step       | What it does                                                                                   |
|------------|------------------------------------------------------------------------------------------------|
| `system`   | apt upgrade, timezone, **unattended security updates**, sysctl network hardening               |
| `user`     | non-root sudo user, **key-only** login, passwordless sudo via `/etc/sudoers.d`                  |
| `ssh`      | custom port, no root, no passwords, `AllowUsers`, validated with `sshd -t` **before** reload    |
| `firewall` | UFW: deny inbound, allow SSH (rate-limited), 80, 443 and any `EXTRA_TCP_PORTS`                 |
| `fail2ban` | sshd jail on the custom port + `recidive` jail for repeat offenders                             |
| `docker`   | Docker Engine + Compose from Docker's repo, container log rotation, `live-restore`              |
| `nginx`    | reverse proxy to your app with security headers, **Let's Encrypt** cert + auto-renew (optional) |
| `backup`   | nightly `tar` of chosen paths **and every Docker volume**, retention, systemd timer             |
| `audit`    | PASS/FAIL checklist of everything above — paste it in your handover note                      |

```
Hardening audit — web-01 — 2026-10-07 09:12:40
  [PASS] root login disabled
  [PASS] password auth disabled
  [PASS] sshd on port 2222
  [PASS] admin user deploy exists
  [PASS] ufw active
  [PASS] fail2ban running
  [PASS] unattended-upgrades enabled
  [PASS] docker running
  [PASS] backup timer enabled
  [PASS] nginx running
  [PASS] TLS cert present for app.example.com
```

## Safety features

* **Idempotent** — every step checks the current state first; run it again after
  changing the config and only the differences are applied.
* **`--dry-run`** prints every command without executing it.
* **No lock-out**: the `ssh` step refuses to disable password login until the
  admin key is actually in `authorized_keys`, validates the config with
  `sshd -t`, and handles Ubuntu's `ssh.socket` port override (a classic trap
  on 22.10+ where changing `Port` in `sshd_config` silently does nothing).
* **`--only step,step`** to re-run a single step, e.g. `--only firewall,audit`.
* Everything is logged to `/var/log/server-bootstrap.log`.

## Layout

```
bootstrap.sh              entry point: arg parsing, config, step runner
bootstrap.conf.example    all settings, documented
lib/common.sh             log/run/dry-run/apt/set_kv/check helpers
lib/step_*.sh             one file per step, each a single function
tests/                    shellcheck + dry-run smoke test (runs in CI, no root)
```

## Tests

```bash
./tests/run.sh      # shellcheck on every script + dry-run against a temp config
```

## Requirements

Ubuntu 22.04 or 24.04, root (or sudo), outbound HTTPS. Nothing else.

MIT License — Florian Whannou
