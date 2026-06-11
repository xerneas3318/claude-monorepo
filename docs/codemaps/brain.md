# codemap — apps/brain/

Markdown-only "second brain". 27 files, ~595 lines.

## Layout

```
brain/
├── CLAUDE.md                   # 188 lines — agent instructions for this notes layout
├── README.md                   #  50 lines — operator notes
├── dashboard.md                #  26 lines — overview anchor
├── daily/
│   ├── today.md                #   8 lines — TODAY (synced + edited by iOS app)
│   ├── future.md               #   8 lines
│   └── history/.gitkeep
├── backlog/
│   ├── tasks.md                #  13 lines — unscheduled
│   ├── upcoming.md             #   8 lines — deadlines
│   └── someday.md              #   5 lines
├── goals/
│   ├── this-week.md            #   5 lines
│   ├── this-month.md           #   5 lines
│   └── long-term.md            #   5 lines
├── projects/
│   └── index.md                #   9 lines
├── routines/
│   ├── daily-routine.md        #   7 lines
│   ├── weekly-routine.md       #  11 lines
│   └── habits.md               #   7 lines
├── memory/
│   ├── context.md              #   9 lines
│   └── decisions.md            #   7 lines
├── notes/
│   └── index.md                #   6 lines
├── templates/
│   ├── project.md              #  65 lines
│   ├── weekly-review.md        #  61 lines
│   ├── note.md                 #  39 lines
│   └── daily.md                #   7 lines
├── archive/.gitkeep
├── LICENSE                     #  21 lines (MIT)
└── .gitignore                  #  22 lines
```

## Conventions

- **Task lines** in markdown use `- [ ] ...` / `- [x] ...`. The parser keys off Nth checkbox in document order — preserve order when editing programmatically.
- **Categories** in `today.md` are top-level `## headings`; tasks under each heading inherit that category.
- **Daily rotation**: `scripts/rotate-today.js` in sync-daemon clears finished items and moves them to `daily/history/YYYY-MM-DD.md` overnight (via the `brain-rotate-today.timer` systemd unit).

## Why it's first-class

The relay's system prompt (`apps/relay/src/claude.js`) embeds these paths verbatim. Renaming a folder breaks Claude's ability to answer correctly. Add new folders freely; rename existing ones only with a coordinated relay update.
