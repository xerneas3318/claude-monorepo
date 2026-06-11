# ClaudePlanner Relay — Server-Side Brief

You are a Claude session running on the user's Hetzner box (root user). The
specific hostname / IP / domain for this deployment lives in `personal.md`
at the project root (gitignored). Read that first if you need the concrete
values.

This directory (`/opt/claudeplanner/relay`) contains a tiny Fastify service
that sits between the user's iPhone and Claude. It's one piece of a larger
system; the rest lives on the user's laptop.

---

## What you are inside of

```
iPhone (SwiftUI)
   │ POST https://<your-subdomain>/talk
   │ Authorization: Bearer <Firebase ID token>
   ▼
Caddy (this box, :443)  ─ TLS, reverse proxy ─►  Fastify (this box, 127.0.0.1:8787)
                                                       │
                                                       ├── verifies Firebase ID token (firebase-admin)
                                                       ├── calls api.anthropic.com (tool-use loop)
                                                       └── reads/writes Firestore (firebase-admin)
                                                                 ▲
                                                                 │
                                                  Laptop sync daemon writes
                                                  the user's markdown planner
                                                  (~/Brain/*.md) to Firestore.
```

The relay never touches the user's laptop or markdown files directly. It only
reads/writes the Firestore mirror. When the relay tells Firestore "task X is
now checked," the laptop daemon picks that up via a Firestore listener and
flips the corresponding line in `~/Brain/daily/today.md`.

---

## What this service does, exactly

`POST /talk` (auth: Bearer Firebase ID token)
  Body: `{ "transcript": "...", "history": [...] }`
  Behavior:
    1. Verifies the Firebase ID token. Optionally enforces `ALLOWED_UIDS`
       allowlist (env). On failure: 401/403.
    2. Sends transcript + history to Anthropic's `messages.create` with the
       four tools below.
    3. Runs the tool-use loop (max 6 rounds): if Claude returns
       `stop_reason=tool_use`, executes the tools and feeds results back in.
    4. Returns `{ reply, history, toolCalls }`.

Tools exposed to Claude:
  - `list_today` — read `users/{uid}/files/daily__today.md/tasks`
  - `check_task({ task_id })` / `uncheck_task({ task_id })` — flip `checked`
  - `read_file({ path })` — fetch the raw markdown of any synced file
    (paths like `daily/today.md`, `backlog/upcoming.md`, etc.)

`GET /healthz` — no auth, returns `{"ok":true}`.

---

## Configuration

All config is environment variables. Production env lives in
`/etc/claudeplanner-relay/.env` (chmod 600, root only). Required:

| Var | Purpose |
|-----|---------|
| `ANTHROPIC_API_KEY` | sk-ant-... — the user's personal Anthropic key. |
| `ANTHROPIC_MODEL` | Default `claude-opus-4-7`. Swap to `claude-haiku-4-5` for ~10× cheaper calls. |
| `FIREBASE_PROJECT_ID` | see `personal.md` |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to the Firebase service-account JSON (same one the laptop daemon uses). |
| `HOST` | Bind address. Should be `127.0.0.1` so only Caddy can reach Node. |
| `PORT` | Default 8787. |
| `ALLOWED_UIDS` | Comma-separated Firebase UIDs allowed to call `/talk`. Pin to the user's UID. |

---

## Operational notes

- Process manager: **systemd** unit `claudeplanner-relay.service` (template in
  `deploy/claudeplanner-relay.service`).
  - `systemctl status claudeplanner-relay`
  - `systemctl restart claudeplanner-relay`
  - `journalctl -u claudeplanner-relay -f` ← tail logs
- TLS: **Caddy** terminates TLS and proxies to `127.0.0.1:8787`. Caddy snippet
  in `deploy/Caddyfile.example`. Caddy auto-renews certs from Let's Encrypt.
- The relay must never listen on a public interface. `HOST=127.0.0.1` is the
  belt-and-suspenders against accidental exposure if Caddy is misconfigured.
- Updating: `git pull && npm ci --omit=dev && systemctl restart claudeplanner-relay`.
- Hardening already in unit: `NoNewPrivileges`, `ProtectSystem=strict`,
  `ProtectHome`, `PrivateTmp`, `ReadOnlyPaths=/etc/claudeplanner-relay`. Runs
  as `www-data`. Do not relax these without a reason.

---

## What NOT to do

- Don't add public-facing endpoints other than `/healthz` and `/talk`. Keep
  attack surface tiny.
- Don't disable the Firebase ID token check, even "just to test." Use the
  health endpoint or a temporary debug route that is removed before commit.
- Don't log full request bodies — they contain user transcripts that may
  include personal info. Log shape/length only.
- Don't store Anthropic conversation history server-side. It's sent and
  echoed back to the client; the client is the source of truth for history.
  This keeps the relay stateless and avoids retention concerns.
- Don't commit `.env` or `service-account.json` (already gitignored).
- Don't widen Firestore rules to do server-side things. The relay
  authenticates as the user (it has Admin SDK), but `ALLOWED_UIDS` is the
  guardrail that ensures it acts only for the intended UID.

---

## Quick triage

| Symptom | Most likely |
|---------|-------------|
| `/talk` 401 | iPhone clock skew, expired Firebase token, or wrong project. |
| `/talk` 403 | UID not in `ALLOWED_UIDS`. |
| `/talk` 500 with "ANTHROPIC_API_KEY env var is required" | .env didn't load — check systemd `EnvironmentFile`. |
| `/talk` 500 with `permission_denied` from Firestore | service-account JSON points at wrong project, or rules block. |
| 502 from Caddy | systemd unit down. `journalctl -u claudeplanner-relay -n 200`. |

---

## Bigger picture

The user is the sole consumer. The whole system exists so they can check off
markdown tasks from their phone, and so they can talk to Claude about their
planner from anywhere. This relay is the bridge for the "talk to Claude"
half. The "check off tasks" half goes phone → Firestore → laptop daemon,
without touching this box.

The full project plan and architecture is in the project root `CLAUDE.md`
on the user's laptop (path documented in `personal.md`).
