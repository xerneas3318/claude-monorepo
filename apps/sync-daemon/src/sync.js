import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { CONFIG } from "../config.js";
import { db, FieldValue } from "./firebase.js";
import { parseForPath } from "./parsers/index.js";

const USER_ID = CONFIG.userId;

// Sync one file: parse it, upsert metadata + tasks to Firestore.
// Idempotent: running twice on the same file produces the same state.
export async function syncFile(relPath) {
  const absPath = join(CONFIG.brainPath, relPath);
  if (!existsSync(absPath)) {
    return deleteFile(relPath); // file was removed; clean Firestore
  }

  const raw = await readFile(absPath, "utf8");
  const parsed = parseForPath(relPath, raw);

  const fileRef = db
    .collection("users")
    .doc(USER_ID)
    .collection("files")
    .doc(encodeFileId(relPath));

  const tasksRef = fileRef.collection("tasks");
  const batch = db.batch();

  batch.set(fileRef, {
    path: relPath,
    kind: parsed.kind,
    title: parsed.title ?? null,
    raw,
    size: raw.length,
    task_count: parsed.tasks.length,
    parsed_at: FieldValue.serverTimestamp(),
    source: CONFIG.nodeId,
    updated_by: CONFIG.nodeId,
  });

  const newIds = new Set();
  for (const t of parsed.tasks) {
    const id = `t${String(t.order).padStart(4, "0")}`;
    newIds.add(id);
    batch.set(tasksRef.doc(id), {
      ...t,
      updated_at: FieldValue.serverTimestamp(),
      updated_by: CONFIG.nodeId,
    });
  }

  // Drop stale tasks (positions that no longer exist).
  const existing = await tasksRef.listDocuments();
  for (const doc of existing) {
    if (!newIds.has(doc.id)) batch.delete(doc);
  }

  await batch.commit();
  console.log(
    `[sync] wrote ${relPath} — ${parsed.kind} (${parsed.tasks.length} tasks, ${raw.length}B)`
  );
}

// Remove a file's doc + its tasks subcollection from Firestore.
export async function deleteFile(relPath) {
  const fileRef = db
    .collection("users")
    .doc(USER_ID)
    .collection("files")
    .doc(encodeFileId(relPath));

  const snap = await fileRef.get();
  if (!snap.exists) {
    return; // nothing to delete
  }

  // recursiveDelete removes the doc and all subcollections atomically (best effort).
  await db.recursiveDelete(fileRef);
  console.log(`[sync] deleted ${relPath}`);
}

// Firestore doc IDs can't contain '/', so encode path separators.
function encodeFileId(relPath) {
  return relPath.replace(/\//g, "__");
}
