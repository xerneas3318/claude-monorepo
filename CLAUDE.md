# ClaudePlanner — Project Brief

This is an iOS + sync daemon implementation of a phone interface for a
local markdown-based planning system (the `Brain/` directory on the
user's laptop). Another Claude agent should read this file at session
start to understand the architecture before doing any work.

> **Before doing anything, also read `personal.md` (gitignored) for
> user-specific identity, paths, Firebase project ID, server hostnames,
> and other context that should never appear in source control.** The
> placeholders in this file (`<personal.md: BRAIN_PATH>`,
> `<personal.md: FIREBASE_PROJECT_ID>`, etc.) resolve from there.

---

## Status

| Component | Status |
|-----------|--------|
| Firebase project | created |
| Firestore | enabled, locked-down rules pinning to the user's UID |
| Service account | configured at the path documented in `personal.md` |
| Sync daemon (laptop ↔ Firestore) | working — see `sync-daemon/` |
| Markdown → Firestore (one-way) | live |
| Firestore → Markdown (write-back) | live (file-level + task-level) |
| iOS app | working — Today + Browse + Talk |
| Voice / Action Button | working via `AppIntent` + Lock Screen widget |
| Background push (FCM) | backlog |
| Gmail + Calendar (readonly) | in progress on the Hetzner box |

---

## What This Is

A native iOS app + macOS sync daemon + Hetzner relay that mirror the
user's local markdown planning files (`Brain/`) to/from Firestore so
the user can view, check off, edit, reorder, and voice-dictate tasks
from their iPhone — and so a remote Claude session (running on the
relay) can act on the same data.

User profile (high-level role, school, etc.) and the exact local paths
live in `personal.md`. Do not duplicate them into this file.

---

## Source of Truth: Markdown Files

The canonical store is **markdown files under `<personal.md: BRAIN_PATH>`**.
Firestore is a synced mirror. The laptop sync daemon (and a second sync
daemon on the Hetzner box) keep them in lockstep.

**Why**: Claude Code on laptop reads the markdown files directly.
Changing that breaks the existing workflow. Markdown remains
authoritative; Firestore is a real-time index that the phone and the
remote relay both subscribe to.

Read `<personal.md: BRAIN_PATH>/CLAUDE.md` for the planner format,
the daily checklist conventions, and the archive protocol. Do not
deviate from those conventions when designing serialization.

---

## Architecture

```
┌──────────────┐   fsevents    ┌──────────────────┐                  ┌──────────────┐
│  Brain/*.md  │ ◄─chokidar──► │ sync-daemon      │ ◄─onSnapshot──► │              │
│  (laptop)    │               │ (laptop)         │  Admin SDK       │              │
└──────────────┘               └──────────────────┘                  │              │
                                                                     │              │
┌──────────────┐   fsevents    ┌──────────────────┐                  │              │
│ /opt/Brain   │ ◄─chokidar──► │ sync-daemon      │ ◄─onSnapshot──► │  Firestore   │
│ (Hetzner)    │               │ (Hetzner)        │  Admin SDK       │              │
└──────────────┘               └──────────────────┘                  │              │
                                                                     │              │
                                ┌──────────────────┐                  │              │
                                │ relay (Fastify)  │ ◄────────────── │              │
                                │ + Claude Agent   │                  │              │
                                │ SDK + MCP tools  │                  │              │
                                └──────────────────┘                  └──────────────┘
                                          ▲                                  ▲
                                          │ POST /talk + Firebase ID token   │ live listeners
                                          │ (HTTPS, UID allowlist)           │ (foreground)
                                          ▼                                  ▼
                                                              ┌──────────────────────┐
                                                              │  iOS app (SwiftUI)   │
                                                              └──────────────────────┘
```

Components:

1. **Firestore (cloud)** — structured task documents, real-time
   listeners, offline cache. Single user; rules pinned to one UID.
2. **macOS sync daemon** (Node.js + chokidar + firebase-admin) —
   bridges markdown ↔ Firestore on the laptop. fsevents-based, zero
   idle CPU. Lives at `sync-daemon/`. Runs as a launchd agent.
3. **Hetzner sync daemon** — same code, second node identity. Mirrors
   Brain on the server so the relay Claude has read/write access to
   the same data the phone sees.
4. **Relay (Fastify on Hetzner)** — public HTTPS endpoint at
   `<personal.md: RELAY_DOMAIN>`. Verifies the phone's Firebase ID
   token, runs Claude via the **Claude Agent SDK** (uses the user's
   Claude subscription rather than the Anthropic API), exposes MCP
   tools (`list_today`, `add_task`, `check_task`, etc.) that operate
   on the local markdown copy and write back to Firestore.
5. **iOS app (SwiftUI, iOS 17+)** — reads/writes Firestore via the
   Firebase SDK, on-device speech via `SFSpeechRecognizer`, TTS via
   `AVSpeechSynthesizer`, App Intent for Lock Screen shortcut.

---

## iOS App Design

### Screens

1. **Today** — checklist grouped by category. Tap to toggle. Long-press
   for context menu (Edit / Move to / Delete). Swipe for edit/delete.
   Drag (in Edit mode) to reorder within a section.
2. **Browse** — list of all synced files; renders raw markdown.
3. **Talk to Claude** — modal sheet: voice (hold to record) or text,
   with model + effort picker, TTS toggle, persistent chat history.
4. **Settings menu** (toolbar) — sign-out.

### Voice / Quick-Access Flow

- **Lock Screen widget** (Shortcuts) and **App Intent** ("Talk to
  Claude") trigger the Talk sheet. The intent forces the app to
  foreground (mic requires foreground).
- **Action Button** (15 Pro+) or **Back Tap** on older phones can run
  the same Shortcut to open the app at the Talk sheet.
- Speech-to-text via `SFSpeechRecognizer` (on-device, no network, no
  battery cost while idle). Mic only opens during user hold.

### Claude Integration

The phone never holds the Claude credential.

- iOS app sends transcript + Firebase ID token to the relay's `/talk`.
- Relay verifies the token (and, if `ALLOWED_UIDS` is set, the UID),
  then runs Claude via `@anthropic-ai/claude-agent-sdk` (`query` with
  an MCP server built from `createSdkMcpServer` / `tool`).
- Tools (server-side):
  - `list_today` — reads today.md from Firestore
  - `read_file(path)`
  - `add_task({ category, text, date? })` — appends to today.md raw
  - `check_task({ task_id })` / `uncheck_task({ task_id })`
  - `move_task({ task_id, new_date })`
- The relay returns `{ reply, history }` to the phone; the phone keeps
  the opaque history blob for follow-up turns.

System prompt is short — describe the planner structure in a few
sentences and refer Claude to the tools rather than reasoning about
markdown directly.

---

## Power Efficiency (NON-NEGOTIABLE)

If you find yourself adding a poll loop, you are doing it wrong.

- **No polling.** Firestore `onSnapshot` listeners. Offline persistence
  via the SDK default cache so most reads never hit network.
- **Listeners only while foregrounded.** Detach on background, re-attach
  on return (`scenePhase`).
- **Background updates via FCM push only** (when wired up).
- **Mic only on user action.** Never always-listening.
- **Debounce rapid writes** (≤200ms coalescing).

Idle phone with app installed should consume effectively zero battery.

---

## Tech Stack

| Layer | Choice |
|-------|--------|
| Phone | SwiftUI (iOS 17+) |
| Auth | Sign in with Apple → Firebase Auth |
| Cloud DB | Firestore (single user, UID-pinned rules) |
| Push (planned) | Firebase Cloud Messaging |
| Claude backend | `@anthropic-ai/claude-agent-sdk` on a self-hosted Fastify relay |
| Speech-to-text | `SFSpeechRecognizer` (on-device) |
| TTS | `AVSpeechSynthesizer` (on-device) |
| Sync daemon | Node.js (24) + firebase-admin + chokidar |
| Daemon runtime | macOS launchd agent (laptop) + systemd unit (Hetzner) |
| Markdown rendering | MarkdownUI |
| Public TLS | Caddy (auto Let's Encrypt) |

Do not introduce new stack pieces without explicit user approval.

---

## Firestore Schema (what the daemons write)

```
users/{uid}/files/{encodedPath}            ← path with '/' replaced by '__'
  - path: "daily/today.md"
  - kind: "today" | "future" | "raw"
  - title: "May 16, 2026 — Saturday"
  - raw: "<full markdown>"
  - size: 1234
  - task_count: 8
  - parsed_at: serverTimestamp
  - source: "laptop" | "claw" | ...
  - updated_by: "laptop" | "claw" | "phone" | "claude"

users/{uid}/files/{encodedPath}/tasks/t0000
  - category: "Physics"
  - text: "E&M studying with Claude"
  - checked: false
  - order: 0
  - date: "2026-05-16"        // only on future.md tasks
  - notes: "<indented body, if any>"
  - updated_at: serverTimestamp
  - updated_by: "laptop" | "claw" | "phone" | "claude"
```

The `uid` is the user's Firebase Auth UID — see `personal.md`. Both
sync daemons must be configured with the same UID and a distinct
`nodeId` (`laptop`, `claw`) so the loop-protection filter
`updated_by !== nodeId` works correctly on each.

---

## Build Phases (history; for context)

1. **Read-only iOS view** — Sign in with Apple, Firestore listener on
   today.md tasks, grouped List. ✅
2. **Bidirectional sync** — phone toggles `checked`, daemon mirrors to
   disk via task-level + file-level watchers. Last-write-wins. ✅
3. **Add / edit tasks from phone** — context menu, swipe actions,
   reorder via `.onMove`, cross-section "Move to…", edit sheet (text,
   notes, category). ✅
4. **Voice + Claude assistant** — relay, MCP tools, model/effort
   picker, TTS, persistent chat. ✅
5. **Background push + power polish** — FCM. ⏳
6. **Polish** — widgets, watch complication, Gmail/Calendar readonly.
   Gmail watcher in progress on the Hetzner box (Ollama PII filter).

---

## Credentials & Configuration

- **`.env` at project root** — gitignored; template in `.env.example`.
- **`personal.md`** — gitignored; user identity, paths, project IDs.
- **iOS Firebase config** — `GoogleService-Info.plist` lives in the
  iOS target. Gitignored (per project preference). Template at
  `ios-app/ClaudePlanner/GoogleService-Info.plist.example`.
- **Anthropic / Claude credential** — never in the phone or in this
  repo. The relay uses the user's Claude subscription via the Agent
  SDK; no API key in source.
- **Firebase service account** — local file outside the repo (see
  `personal.md` for the path). `chmod 600`.
- **Relay env** — `/etc/claudeplanner-relay/.env` on the server;
  contains `FIREBASE_SERVICE_ACCOUNT_JSON`, `ALLOWED_UIDS`, etc.
- **Hetzner sync daemon env** — `/etc/brain-sync-claw/.env`; same
  service-account JSON plus `BRAIN_SYNC_NODE_ID=claw` and the user's
  UID.

---

## Repository Layout

```
ClaudePlanner/
├── CLAUDE.md                ← this file (public)
├── personal.md              ← gitignored; user-specific identity & paths
├── .env.example             ← template; copy to .env, fill in
├── .gitignore
├── sync-daemon/             ← Node.js + firebase-admin + chokidar
│   ├── package.json
│   ├── config.js
│   ├── src/
│   │   ├── firebase.js
│   │   ├── sync.js
│   │   ├── watcher.js
│   │   ├── firestore-watcher.js
│   │   ├── index.js
│   │   └── parsers/
│   ├── scripts/
│   │   ├── test-connection.js
│   │   ├── sync-once.js
│   │   └── rotate-today.js
│   └── deploy/              ← systemd units for the Hetzner node
├── ios-app/                 ← Xcode project (xcodegen-managed)
│   ├── project.yml
│   ├── bootstrap.sh
│   └── ClaudePlanner/
└── relay/                   ← Fastify gateway on Hetzner
    ├── package.json
    ├── src/
    │   ├── claude.js
    │   ├── firebase.js
    │   ├── tools.js
    │   └── index.js
    └── deploy/
```

---

## What NOT To Do

- **Don't change anything in `<personal.md: BRAIN_PATH>`** without
  explicit user instruction. The sync daemons are the only things
  allowed to write there, via the documented protocol.
- **Don't put any user-identifying info into this file or any other
  tracked file.** All such facts go in `personal.md`.
- **Don't ship the Claude / Anthropic credential anywhere except the
  relay's env file.**
- **Don't poll.** If you write a `setInterval` or
  `Timer.scheduledTimer(.repeating:)`, stop and reconsider. Firestore
  `onSnapshot` and `NotificationCenter`/Combine exist for a reason.
- **Don't introduce new dependencies** beyond the stack table above
  without user approval.
- **Don't use CocoaPods.** Swift Package Manager only.
- **Don't build a web app or PWA.** Native iOS only.
- **Don't expose any data publicly.** Firestore rules pinned to the
  user's UID.
- **Don't write to GitHub as the sync layer.** Considered and
  rejected.
- **Don't add emojis to code, commits, or UI strings unless the user
  requests them.**
- **Don't summarize what you just did at the end of every response.**
  The user finds it noisy.

---

## Style & Process

- Concise responses, no fluff.
- Confirm before destructive actions (deleting branches, rewriting
  history, pushing to remote, regenerating service-account keys).
- When the user provides a URL, treat it as authoritative and read it.
- Match the existing code style.

---

## Related Reading

- `personal.md` — user-specific context (gitignored).
- `<personal.md: BRAIN_PATH>/CLAUDE.md` — Brain system's own
  instructions, including the planner format and archive protocol.
- `relay/CLAUDE.md` — instructions for Claude sessions running on the
  Hetzner box (relay + email watcher + 2nd sync daemon).
- `sync-daemon/deploy/CLAW_DEPLOY.md` — how the daemon is installed
  and operated on the Hetzner node.

---

## Prior Art

- https://github.com/Psypeal/claude-knowledge-vault
- https://github.com/eugeniughelbur/obsidian-second-brain
