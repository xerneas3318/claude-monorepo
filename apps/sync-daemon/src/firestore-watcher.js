// Firestore -> markdown write-back.
//
// Two listeners:
//   1. Task-level watcher (today.md only): flips Nth checkbox in place. Fast
//      path for the common case of toggling a single task from the phone.
//   2. File-level watcher (all files): writes `raw` content to local disk when
//      Firestore has newer content than the file system. This is what makes
//      this daemon usable as a 2nd sync node (e.g. on a Hetzner box).
//
// Loop protection:
//   - Skip any change where `updated_by === CONFIG.nodeId` (our own write).
//   - File-level write is idempotent: if local content matches Firestore, skip.

import { readFile, writeFile, mkdir, stat } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { CONFIG } from "../config.js";
import { db } from "./firebase.js";

// Tolerance on the local-vs-remote timestamp comparison. fs mtime and Firestore
// server timestamps come from different clocks; a small skew shouldn't cause
// remote writes to be wrongly accepted as "newer". A few seconds is enough to
// absorb routine clock drift while still being responsive to real edits.
const MTIME_SKEW_MS = 5000;

const USER_ID = CONFIG.userId;
const NODE_ID = CONFIG.nodeId;

const TASK_WATCHED_FILES = [
  { fileId: "daily__today.md", relPath: "daily/today.md" },
];

export function watchFirestore() {
  watchTasks();
  watchFiles();
}

function watchTasks() {
  for (const { fileId, relPath } of TASK_WATCHED_FILES) {
    const tasksRef = db
      .collection("users").doc(USER_ID)
      .collection("files").doc(fileId)
      .collection("tasks");

    tasksRef.onSnapshot(
      (snap) => {
        for (const change of snap.docChanges()) {
          if (change.type === "removed") continue;
          const data = change.doc.data();
          if (!data || data.updated_by === NODE_ID) continue;
          handleTaskChange(relPath, data).catch((e) =>
            console.error(`[fs->md tasks] error for ${relPath}: ${e.message}`)
          );
        }
      },
      (e) => console.error(`[fs->md tasks] watcher error for ${relPath}: ${e.message}`)
    );

    console.log(`[fs->md tasks] watching ${relPath}`);
  }
}

function watchFiles() {
  const filesRef = db.collection("users").doc(USER_ID).collection("files");

  filesRef.onSnapshot(
    (snap) => {
      for (const change of snap.docChanges()) {
        if (change.type === "removed") {
          // Don't auto-delete local files. Surfaces a manual decision instead.
          const data = change.doc.data();
          console.warn(`[fs->md files] doc removed: ${data?.path ?? change.doc.id} (local file left in place)`);
          continue;
        }
        const data = change.doc.data();
        if (!data || data.updated_by === NODE_ID) continue;
        if (typeof data.path !== "string" || typeof data.raw !== "string") continue;
        const parsedAtMs = data.parsed_at?.toMillis?.() ?? null;
        handleFileChange(data.path, data.raw, data.updated_by, parsedAtMs).catch((e) =>
          console.error(`[fs->md files] error for ${data.path}: ${e.message}`)
        );
      }
    },
    (e) => console.error(`[fs->md files] watcher error: ${e.message}`)
  );

  console.log(`[fs->md files] watching users/${USER_ID}/files (node=${NODE_ID})`);
}

async function handleTaskChange(relPath, task) {
  const absPath = join(CONFIG.brainPath, relPath);
  if (!existsSync(absPath)) return;
  const raw = await readFile(absPath, "utf8");
  const eol = raw.includes("\r\n") ? "\r\n" : "\n";
  const lines = raw.split(/\r?\n/);

  let count = 0;
  let changed = false;
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^(\s*-\s*)\[( |x|X)\](\s+.+)$/);
    if (!m) continue;
    if (count === task.order) {
      const currentlyChecked = m[2].toLowerCase() === "x";
      if (currentlyChecked !== task.checked) {
        lines[i] = `${m[1]}[${task.checked ? "x" : " "}]${m[3]}`;
        changed = true;
      }
      break;
    }
    count++;
  }

  if (changed) {
    await writeFile(absPath, lines.join(eol), "utf8");
    console.log(`[fs->md tasks] ${relPath} order=${task.order} -> ${task.checked ? "[x]" : "[ ]"}`);
  }
}

async function handleFileChange(relPath, newRaw, updatedBy, remoteMtimeMs) {
  const absPath = join(CONFIG.brainPath, relPath);
  let currentRaw = null;
  let localMtimeMs = null;
  if (existsSync(absPath)) {
    currentRaw = await readFile(absPath, "utf8");
    localMtimeMs = (await stat(absPath)).mtimeMs;
  }
  if (currentRaw === newRaw) return;

  // Last-write-wins by timestamp. Skip stale remote writes that would clobber
  // a fresher local edit — this is what fixes "ghost reappearing" lines when
  // the daemon restarts and replays old Firestore docs, or when another node
  // (e.g. hetzner) pushes content older than the user's last local change.
  if (
    localMtimeMs !== null &&
    remoteMtimeMs !== null &&
    remoteMtimeMs + MTIME_SKEW_MS < localMtimeMs
  ) {
    console.log(
      `[fs->md files] skip stale ${relPath} from=${updatedBy} ` +
      `(remote=${new Date(remoteMtimeMs).toISOString()} < local=${new Date(localMtimeMs).toISOString()})`
    );
    return;
  }

  await mkdir(dirname(absPath), { recursive: true });
  await writeFile(absPath, newRaw, "utf8");
  console.log(`[fs->md files] wrote ${relPath} from=${updatedBy} (${newRaw.length}B)`);
}
