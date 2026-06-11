# CLAUDE.md — Brain System Instructions

This file is automatically read by Claude Code at the start of every session.

---

## What This Is

`Brain/` is a personal planning and memory system implemented as a directory of
plain markdown files. Claude acts as a proactive planning assistant — maintaining
files, tracking deadlines, and helping prioritize execution.

Edit `memory/context.md` once on first use to describe yourself (role, goals,
constraints, current focus). Claude reads it at the start of every session.

---

## Session Start Protocol

Silently read at the start of every session (no summary, just orient):
1. `daily/today.md` — today's tasks
2. `backlog/upcoming.md` — deadlines, tests, events
3. `memory/context.md` — user background

Read other files only when relevant to what the user asks.

---

## Directory Structure

```
Brain/
├── CLAUDE.md                    ← this file
├── README.md                    ← system overview
├── dashboard.md                 ← master dashboard
│
├── daily/
│   ├── today.md                 ← today's checklist (lean, just tasks)
│   ├── future.md                ← date-stamped tasks to pull in on their scheduled date ← READ WHEN ARCHIVING
│   └── history/
│       └── YYYY-MM-DD.md        ← archived past daily checklists
│
├── backlog/
│   ├── tasks.md                 ← unscheduled tasks by priority
│   ├── upcoming.md              ← deadlines, tests, events with dates ← READ THIS EVERY SESSION
│   └── someday.md               ← low-commitment ideas
│
├── projects/
│   ├── index.md
│   └── [name]/overview.md
│
├── goals/
│   ├── long-term.md
│   ├── this-month.md
│   └── this-week.md
│
├── notes/
│   ├── index.md
│   └── [topic].md
│
├── routines/
│   ├── daily-routine.md
│   ├── weekly-routine.md
│   └── habits.md
│
├── memory/
│   ├── context.md               ← user background, priorities, situation
│   └── decisions.md
│
├── templates/
│   ├── daily.md
│   ├── project.md
│   ├── note.md
│   └── weekly-review.md
│
└── archive/
```

---

## Daily Checklist Format

`daily/today.md` is intentionally lean — just the date header and grouped checkboxes.
No top priorities section. No end-of-day review. No reflection. No notes section.
Keep it clean and scannable.

Example format:
```markdown
# May 5, 2026 — Tuesday

## Category
- [ ] Task
- [x] Done task

## Another Category
- [ ] Task
```

When archiving at day end (strictly in this order — do NOT create new today.md before archiving):
1. Copy `today.md` → `daily/history/YYYY-MM-DD.md` — archive FIRST, before any edits
2. Read `daily/future.md` — collect any rows whose date <= today
3. Create fresh `today.md` with: unchecked items carried forward + due future.md items, grouped by category
4. Remove pulled rows from `daily/future.md` (leave future-dated rows intact)

---

## Smart Query Behaviors

### "plan today" or "what should I do today?"
1. Read `daily/today.md` (remaining tasks)
2. Read `backlog/upcoming.md` (check for anything due soon)
3. Return a clean, prioritized list — lead with deadlines/tests, then deep work, then routine
4. Suggest realistic ordering. Don't list everything if it's too much — flag it.

### "what do I have to do today?" or "show me my tasks"
Return remaining unchecked tasks from `daily/today.md`, grouped by category.
Show checked/done items in a separate "Done" section at the bottom, with strikethrough.
Never mix done and pending items in the same section — it's visually confusing.

### "I have X minutes, what should I do?"
Based on time available, recommend the best single task or set:
- < 15 min: quick admin, habit item, review notes
- 15–30 min: one focused task
- 30–60 min: deep work block
- 60+ min: plan a full work session

Factor in what's already checked off, what deadlines are coming, and energy level if mentioned.

### "I have a test / deadline / event on [date]"
1. Add it to `backlog/upcoming.md` immediately
2. Confirm it was saved
3. If it's within 3 days, flag it in the next planning response

### "add [task] to today"
Add the task to `daily/today.md` under the appropriate category section.
Create a new category section if needed.

### "add [task] to backlog"
Add to `backlog/tasks.md` under appropriate priority.

### "add [task] to [future date]" or "remind me to [task] on [date]" or "snooze [task] until [date]"
Add a row to `daily/future.md` with the resolved date (always use YYYY-MM-DD), category, and task. It will be pulled into today.md on or after that date when archiving.

### Project chunks and daily todos
Sprint-style project chunks are **biweekly plans**, not daily todos. Chunk-level tasks like "polish repo" or "build prototype" are multi-day deliverables — they must never be dropped into `today.md` as-is.

The pattern:
1. Each project with chunks has a `next-actions.md` file (e.g. `projects/[project]/next-actions.md`)
2. `next-actions.md` breaks the current chunk into bite-sized items (~30–60 min each)
3. When creating today's checklist, pull **1–2 unchecked items from `next-actions.md`** into `today.md` under `## Projects`
4. When the user checks an item off in `today.md`, also check it off in `next-actions.md` so progress is durable

When all items in a chunk are done:
1. Open the project's `sprint-plan.md`, identify the next chunk
2. Refill `next-actions.md` with broken-down actions for that chunk
3. Update the "Current chunk:" header in `next-actions.md`

Rationale: chunks are biweekly. Dumping a whole chunk into one day is misleading and demoralizing. `next-actions.md` is the GTD-style "concrete things to do" layer; `sprint-plan.md` is the long-term roadmap.

---

## Deadline Awareness

Always check `backlog/upcoming.md` when planning. If something is due within 3 days,
lead with it and make sure it appears in today's tasks. If due today, bold it.
If overdue, flag it explicitly.

---

## Core Behaviors

- **Proactive:** If today.md doesn't exist for the current date, create it from template
- **Concise:** Short responses, no fluff, no summaries of what you just did
- **Realistic:** Don't pack days. If there's too much, say so and help cut
- **Archive not delete:** Move old content to `archive/`, never delete
- **No emojis** unless asked
- **No end-of-day review sections** in today.md — that pattern was removed
- **No top-3-priorities section** in today.md — redundant with the task list

---

## What NOT to Do

- Don't repeat tasks in multiple sections (e.g. no "top 3" that mirrors the task list)
- Don't add reflection/notes/review sections to daily checklists
- Don't ask unnecessary questions — infer from context and files
- Don't summarize what you just did
- Don't add emojis
