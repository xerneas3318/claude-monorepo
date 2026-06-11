// Daily rotation of daily/today.md.
//
// Implements the archive protocol from Brain/CLAUDE.md:
//   1. If today.md's title date != today (local), archive it to
//      daily/history/YYYY-MM-DD.md (using the date IN the title).
//   2. Collect unchecked items from the old today.md (carry-overs).
//   3. Read daily/future.md, pull rows with date <= today.
//   4. Write a fresh today.md grouped by category, with carry-overs first.
//   5. Strip pulled rows from future.md.
//
// Idempotent: if today.md already has today's date, do nothing.
//
// Designed to run from a systemd timer on the Hetzner node. The local file
// change is picked up by chokidar -> sync.js, which syncs to Firestore,
// which the phone listener picks up.

import { readFile, writeFile, mkdir, rename } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";

const BRAIN = process.env.BRAIN_PATH || "/opt/Brain";
const TODAY_PATH = join(BRAIN, "daily/today.md");
const HISTORY_DIR = join(BRAIN, "daily/history");
const FUTURE_PATH = join(BRAIN, "daily/future.md");

const MONTHS = [
  "January","February","March","April","May","June",
  "July","August","September","October","November","December",
];
const WEEKDAYS = [
  "Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday",
];

function localDateParts(d = new Date()) {
  // Respect TZ env var (systemd unit sets it to America/New_York)
  return {
    year:  d.getFullYear(),
    month: d.getMonth(),
    day:   d.getDate(),
    weekday: d.getDay(),
  };
}

function formatTitle(d = new Date()) {
  const p = localDateParts(d);
  return `${MONTHS[p.month]} ${p.day}, ${p.year} — ${WEEKDAYS[p.weekday]}`;
}

function isoDate(d = new Date()) {
  const p = localDateParts(d);
  return `${p.year}-${String(p.month + 1).padStart(2, "0")}-${String(p.day).padStart(2, "0")}`;
}

// Parse "May 16, 2026 — Saturday" → "2026-05-16". Returns null on failure.
function parseTitleToDate(title) {
  if (!title) return null;
  const m = title.match(/^([A-Za-z]+)\s+(\d{1,2}),\s+(\d{4})/);
  if (!m) return null;
  const monthIdx = MONTHS.findIndex((x) => x.toLowerCase() === m[1].toLowerCase());
  if (monthIdx < 0) return null;
  const day = parseInt(m[2], 10);
  const year = parseInt(m[3], 10);
  return `${year}-${String(monthIdx + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

// Pull unchecked tasks (with their indented notes) from old today.md,
// grouped by category, preserving order.
function parseUncheckedByCategory(raw) {
  const out = []; // [{ category, text, notes }]
  let category = "Uncategorized";
  let current = null;
  const noteBuf = [];

  function flush() {
    if (current) {
      while (noteBuf.length && noteBuf[noteBuf.length - 1].trim() === "") noteBuf.pop();
      current.notes = noteBuf.length ? noteBuf.join("\n") : "";
      noteBuf.length = 0;
      current = null;
    }
  }

  for (const line of raw.split(/\r?\n/)) {
    if (line.startsWith("## ")) { flush(); category = line.slice(3).trim(); continue; }
    if (line.startsWith("# "))  { flush(); continue; }
    const unchecked = line.match(/^-\s*\[ \]\s+(.+?)\s*$/);
    if (unchecked) {
      flush();
      current = { category, text: unchecked[1], notes: "" };
      out.push(current);
      continue;
    }
    // Checked task ends any in-progress notes (we drop it).
    if (/^-\s*\[x\]/i.test(line)) { flush(); continue; }
    // Indented content belongs to the current task.
    if (current && (line.startsWith("  ") || line.startsWith("\t"))) {
      noteBuf.push(line.replace(/^( {2}|\t)/, ""));
      continue;
    }
    if (line.trim() === "" && current) { noteBuf.push(""); continue; }
    flush();
  }
  flush();
  return out;
}

// Read future.md, pull rows with date <= todayISO. Returns:
//   { pulled: [{ category, text }], remaining_raw: string }
function pullDueFuture(raw, todayIso) {
  const lines = raw.split(/\r?\n/);
  const pulled = [];
  const keptLines = [];
  for (const line of lines) {
    if (!line.includes("|")) { keptLines.push(line); continue; }
    const cells = line.split("|").map((c) => c.trim());
    const inner = cells.filter((_, i) => i !== 0 && i !== cells.length - 1);
    if (inner.length !== 3) { keptLines.push(line); continue; }
    const [date, category, task] = inner;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !task) { keptLines.push(line); continue; }
    if (date <= todayIso) {
      pulled.push({ category, text: task });
    } else {
      keptLines.push(line);
    }
  }
  return { pulled, remaining_raw: keptLines.join("\n") };
}

function renderToday(title, items) {
  // Group by category, preserving first-seen category order.
  const seen = [];
  const buckets = new Map();
  for (const it of items) {
    if (!buckets.has(it.category)) {
      seen.push(it.category);
      buckets.set(it.category, []);
    }
    buckets.get(it.category).push(it);
  }
  const parts = [`# ${title}`, ""];
  for (const cat of seen) {
    parts.push(`## ${cat}`);
    for (const it of buckets.get(cat)) {
      parts.push(`- [ ] ${it.text}`);
      if (it.notes) {
        for (const noteLine of it.notes.split(/\r?\n/)) {
          parts.push(noteLine ? `  ${noteLine}` : "");
        }
      }
    }
    parts.push("");
  }
  return parts.join("\n");
}

async function run() {
  const today = new Date();
  const newTitle = formatTitle(today);
  const todayIso = isoDate(today);

  if (!existsSync(TODAY_PATH)) {
    console.log(`[rotate] today.md missing — creating empty for ${newTitle}`);
    await mkdir(join(BRAIN, "daily"), { recursive: true });
    await writeFile(TODAY_PATH, `# ${newTitle}\n\n`, "utf8");
    return;
  }

  const oldRaw = await readFile(TODAY_PATH, "utf8");
  const oldTitleMatch = oldRaw.match(/^#\s+(.+?)\s*$/m);
  const oldTitle = oldTitleMatch ? oldTitleMatch[1] : null;

  if (oldTitle === newTitle) {
    console.log(`[rotate] today.md already current (${newTitle})`);
    return;
  }

  // Archive old today.md under the date parsed from its title.
  // Fall back to yesterday's date if parsing fails.
  const archiveIso = parseTitleToDate(oldTitle) || isoDate(new Date(today.getTime() - 86400000));
  await mkdir(HISTORY_DIR, { recursive: true });
  const archivePath = join(HISTORY_DIR, `${archiveIso}.md`);
  if (existsSync(archivePath)) {
    console.log(`[rotate] archive ${archivePath} exists — overwriting`);
  }
  await writeFile(archivePath, oldRaw, "utf8");
  console.log(`[rotate] archived: ${oldTitle} -> ${archivePath}`);

  // Carry-overs from yesterday's unchecked items.
  const carriedItems = parseUncheckedByCategory(oldRaw);

  // Pull due rows from future.md.
  let futureItems = [];
  if (existsSync(FUTURE_PATH)) {
    const futureRaw = await readFile(FUTURE_PATH, "utf8");
    const { pulled, remaining_raw } = pullDueFuture(futureRaw, todayIso);
    futureItems = pulled;
    if (pulled.length > 0) {
      await writeFile(FUTURE_PATH, remaining_raw, "utf8");
      console.log(`[rotate] pulled ${pulled.length} item(s) from future.md`);
    }
  }

  const items = [...carriedItems, ...futureItems];
  const fresh = renderToday(newTitle, items);
  await writeFile(TODAY_PATH, fresh, "utf8");
  console.log(`[rotate] wrote fresh today.md: ${newTitle} (${items.length} items)`);
}

run().catch((e) => {
  console.error(`[rotate] error: ${e.stack || e.message}`);
  process.exit(1);
});
