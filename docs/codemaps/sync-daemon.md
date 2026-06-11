# codemap — apps/sync-daemon/

Node long-running process. Two-way sync between `brain/*.md` on disk and Firestore. 20 files (937 src/script lines, plus a 2135-line package-lock).

## File map

```
sync-daemon/
├── package.json                          # name=brain-sync-daemon
├── package-lock.json                     # 2135 lines
├── README.md                             #  31 lines
├── config.js                             #  22 lines — paths, userId, nodeId, debounce
├── .gitignore                            #   4 lines
├── src/
│   ├── index.js                          #  16 lines — entry: watch + watchFirestore
│   ├── watcher.js                        #  50 lines — chokidar on brain/**/*.md
│   ├── sync.js                           #  86 lines — parse + upsert to Firestore
│   ├── firestore-watcher.js              # 148 lines — task + file listeners
│   ├── firebase.js                       #  27 lines — Admin SDK (3 cred paths)
│   └── parsers/
│       ├── index.js                      #  20 lines — dispatch by path
│       ├── today.js                      #  74 lines — daily/today.md tasks
│       └── future.js                     #  38 lines — daily/future.md tasks
├── scripts/
│   ├── rotate-today.js                   # 212 lines — overnight archive of today.md
│   ├── sync-once.js                      #  47 lines — one-shot full upsert
│   └── test-connection.js                #  59 lines — sanity check Firestore creds
└── deploy/
    ├── brain-sync-claw.service           #  22 lines — main daemon (systemd)
    ├── brain-rotate-today.service        #  17 lines — one-shot rotation
    ├── brain-rotate-today.timer          #  12 lines — fires at 00:05 local
    └── CLAW_DEPLOY.md                    #  33 lines — deploy runbook
```

## Entry points

| function                | file                   | role                                                         |
| ----------------------- | ---------------------- | ------------------------------------------------------------ |
| `watch({onChange, ...})`| `src/watcher.js`       | chokidar; filters `*.md`; ignores `.git`/`.obsidian`/`.claude` |
| `syncFile(path)`        | `src/sync.js`          | parse + upsert metadata + tasks                              |
| `deleteFile(path)`      | `src/sync.js`          | mark Firestore doc deleted                                   |
| `watchFirestore()`      | `src/firestore-watcher.js` | task + file listeners; writes back to disk              |
| `parseForPath(path, raw)` | `src/parsers/index.js` | route to per-file parser                                   |

## Firestore schema (what this writes)

```
users/{uid}/
  ├── files/{fileId}
  │     ├── path        # "daily/today.md"
  │     ├── raw         # full markdown
  │     ├── nodeId      # last writer
  │     └── updatedAt   # serverTimestamp
  └── tasks/{taskId}
        ├── fileId
        ├── category
        ├── text
        ├── checked
        └── order       # nth checkbox in document
```

`fileId` is the path with `/` → `__` (e.g. `daily__today.md`). Keep this transformation stable.

## Two-way safety

`firestore-watcher.js` tags each disk-write with the local `nodeId` to suppress its own chokidar event, and also uses a short ignore-window per file. If the loop ever fires, the daemon logs a warning and breaks out.

## Run

```bash
cd apps/sync-daemon
npm install
npm run test:connection      # verify creds
npm start                    # foreground
# or via systemd: deploy/brain-sync-claw.service
```

## Scripts

| script              | use                                                  |
| ------------------- | ---------------------------------------------------- |
| `sync-once`         | initial seed of Firestore from current brain/        |
| `test-connection`   | prints whoami + collection counts                    |
| `rotate-today`      | archives finished today.md into `daily/history/`     |
