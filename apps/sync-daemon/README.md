# brain-sync-daemon

Bidirectional sync between Brain markdown files and Firestore.
Event-driven, zero idle CPU.

## Setup

1. Service account JSON at `~/.config/brain-sync/service-account.json`
2. Brain folder at `~/Brain`
3. Node 18+

```
cd ~/projects/ClaudePlanner/sync-daemon
npm install
npm run test:connection
```

If the connection test passes, you're ready to add sync logic.

## Power architecture

- File watching: `chokidar` → macOS `fsevents` (kernel-level, push)
- Firestore listening: `onSnapshot` (gRPC streaming, push)
- No polling, no periodic timers (except 500ms write debouncer)
- launchd starts the daemon at login; auto-restarts on crash only

## Files

- `config.js` — paths, watched files, debounce window, project id
- `scripts/test-connection.js` — one-off Firestore reachability test
- `src/index.js` — entry point (not yet written)
