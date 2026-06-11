# Brain — Personal Planning & Memory System

> A local markdown-based system for organizing your life, work, and thinking.

## How It Works

Everything lives as plain markdown files — human-readable, editable, searchable, and yours.
Claude reads only the relevant files for each session and updates them automatically.

---

## Navigation

| Area | File | Purpose |
|------|------|---------|
| **Dashboard** | [dashboard.md](dashboard.md) | Today's focus, priorities, quick links |
| **Today** | [daily/today.md](daily/today.md) | Today's checklist (replaced each day) |
| **History** | [daily/history/](daily/history/) | All past daily checklists, one per day |
| **Projects** | [projects/index.md](projects/index.md) | All active & paused projects |
| **Backlog** | [backlog/tasks.md](backlog/tasks.md) | Unscheduled tasks to do eventually |
| **Someday** | [backlog/someday.md](backlog/someday.md) | Ideas and low-priority items |
| **Goals** | [goals/](goals/) | Long-term, monthly, and weekly goals |
| **Notes** | [notes/index.md](notes/index.md) | Topic-based notes and knowledge |
| **Routines** | [routines/](routines/) | Daily/weekly routines and habit tracking |
| **Memory** | [memory/](memory/) | Important long-term context for Claude |
| **Templates** | [templates/](templates/) | Reusable templates |
| **Archive** | [archive/](archive/) | Old content, kept for reference |

---

## System Rules

1. **Today's checklist** is always at `daily/today.md`. At end of day, it gets archived to `daily/history/YYYY-MM-DD.md`.
2. **Projects** each get their own folder under `projects/` with an `overview.md`.
3. **Notes** are topic-based files under `notes/`. New topics get new files.
4. **Memory** files capture context that matters across sessions (not ephemeral).
5. **Archive** rather than delete — move old content to `archive/` with a date prefix.
6. **Backlog** items graduate to daily checklists or projects when scheduled.

---

## Evolution

This system grows with you. Claude will:
- Create new folders/files when needed
- Refactor when things get messy
- Suggest structural improvements over time
- Keep the index files up to date

Last updated: 2026-05-05
