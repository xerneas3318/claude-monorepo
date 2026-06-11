# codemap — apps/relay/

Fastify server on `:8787` that wraps Claude with Firestore-backed tools. 12 files, ~614 lines.

## File map

```
relay/
├── package.json              # name=claudeplanner-relay; scripts: start, dev
├── README.md                 # 155 lines — local + production deploy notes
├── CLAUDE.md                 # 137 lines — agent instructions for this codebase
├── .env.example              #  24 lines — see "env" below
├── .gitignore                #   4 lines
├── src/
│   ├── index.js              #  65 lines — Fastify bootstrap, auth, POST /talk
│   ├── claude.js             #  71 lines — Anthropic SDK + tool-use loop
│   ├── tools.js              #  85 lines — tool defs + Firestore impls
│   └── firebase.js           #  15 lines — firebase-admin init
└── deploy/
    ├── claudeplanner-relay.service  # 22 lines — systemd unit
    ├── Caddyfile                    #  4 lines
    └── Caddyfile.example            # 14 lines
```

## Entry points

| function / route               | file        | purpose                                          |
| ------------------------------ | ----------- | ------------------------------------------------ |
| `POST /talk`                   | `index.js`  | main endpoint: text in, text reply out           |
| `runClaude({...})`             | `claude.js` | Messages API call + tool-use loop (≤6 rounds)    |
| `buildTools()` / `executeTool` | `tools.js`  | tool registry; touches Firestore admin SDK       |

## Tools exposed to Claude

| name           | input              | what it does                                       |
| -------------- | ------------------ | -------------------------------------------------- |
| `list_today`   | `{}`               | returns ordered today.md tasks {id, category, text, checked} |
| `check_task`   | `{id}`             | sets `checked=true` (and back-propagates via sync) |
| `uncheck_task` | `{id}`             | inverse                                            |
| `read_file`    | `{fileId}`         | returns raw markdown of a tracked file             |
| *(more)*       | see `tools.js`     | full set lives in `src/tools.js`                   |

## Constants

- `MODEL = "claude-opus-4-7"` *(override with `ANTHROPIC_MODEL`)*
- `MAX_TOKENS = 1024`
- `MAX_TOOL_ROUNDS = 6`

## System prompt (excerpt)

> "You are the user's personal planning assistant on their phone. Their planner lives in markdown at ~/Brain/, mirrored to Firestore. Today's tasks are in daily/today.md … Use the provided tools to read and act on the planner — never invent task ids. Always call list_today before claiming what's on the list."

## Env

| var                              | required | default        |
| -------------------------------- | -------- | -------------- |
| `ANTHROPIC_API_KEY`              | yes      | —              |
| `ANTHROPIC_MODEL`                | no       | claude-opus-4-7|
| `ALLOWED_UIDS`                   | yes      | (empty = none) |
| `HOST`                           | no       | 127.0.0.1      |
| `PORT`                           | no       | 8787           |
| `GOOGLE_APPLICATION_CREDENTIALS` | yes      | —              |

## Run

```bash
cd apps/relay
npm install
cp .env.example .env && $EDITOR .env
npm run dev   # or: npm start
```

Production: see `deploy/claudeplanner-relay.service` (runs under `node src/index.js`, behind Caddy).
