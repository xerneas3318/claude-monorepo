# Personal Context (gitignored — never commit)

This file holds user-specific identifiers, paths, and profile context that
should never leave the local machine. The public `CLAUDE.md` and the other
docs reference this file but do not embed its contents.

If you (Claude) are starting a new session on this repo, read this file
first to fill in the placeholders used throughout `CLAUDE.md`.

---

## User profile

- High-school senior heading to Cornell CS in fall 2026.
- Runs a local markdown-based planning system in `~/Brain/`. Reads / edits
  it from a laptop via Claude Code; mirrors it to phone via the iOS app +
  Firestore.
- Email: `frc10252@gmail.com`.
- GitHub: `xerneas3318` (noreply email `184197860+xerneas3318@users.noreply.github.com`).

## Local paths

| Variable           | Value                                                     |
|--------------------|-----------------------------------------------------------|
| Brain repo         | `/Users/xerneas/Brain/`                                   |
| ClaudePlanner repo | `/Users/xerneas/projects/ClaudePlanner/`                  |
| Service account    | `~/.config/brain-sync/service-account.json` (chmod 600)   |
| Google OAuth (future) | `~/.config/brain-sync/google-oauth.json` (chmod 600)   |

## Firebase

| Field              | Value                  |
|--------------------|------------------------|
| Project ID         | `claudeplanner-59e43`  |
| Firebase UID (Apple sign-in) | `jmewd1c99bZfMPDknwb5udQGmZH2` |

The sync daemon (laptop and server) must run with
`BRAIN_SYNC_USER_ID=jmewd1c99bZfMPDknwb5udQGmZH2` so it reads/writes the
same Firestore subtree as the phone.

## iOS / Apple

| Field              | Value          |
|--------------------|----------------|
| Apple Team ID      | `627B5YTK7V`   |
| App Bundle ID      | `com.xerneas.claudeplanner` |
| Firebase iOS App ID | `1:1090296947589:ios:8dd42abf57f9427cafdaec` |

## Hetzner server (relay + 2nd sync node)

| Field              | Value                       |
|--------------------|-----------------------------|
| Hostname (tailnet) | `openclaw-1`                |
| Public IPv4        | `204.168.171.0`             |
| Relay domain       | `relay.dream-canvas.ai`     |
| Relay env file     | `/etc/claudeplanner-relay/.env` |
| Sync daemon env    | `/etc/brain-sync-claw/.env` |
| Brain mirror path  | `/opt/Brain/`               |
| Email watcher dir  | `/opt/email-watcher/`       |

## DNS

`relay.dream-canvas.ai` → A record `204.168.171.0` on Hostinger, TTL 14400.
Caddy on the server terminates TLS via Let's Encrypt automatically.
