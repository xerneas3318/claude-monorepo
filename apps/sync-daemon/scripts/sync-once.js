// One-shot manual sync.
// Usage:
//   node scripts/sync-once.js                  (sync all .md files in Brain)
//   node scripts/sync-once.js daily/today.md   (sync specific files)

import { readdir } from "node:fs/promises";
import { join, relative } from "node:path";
import { syncFile } from "../src/sync.js";
import { CONFIG } from "../config.js";

async function findAllMarkdown(root) {
  const results = [];
  async function walk(dir) {
    const entries = await readdir(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name.startsWith(".")) continue; // skip hidden
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        await walk(full);
      } else if (entry.isFile() && entry.name.endsWith(".md")) {
        results.push(relative(root, full));
      }
    }
  }
  await walk(root);
  return results.sort();
}

const args = process.argv.slice(2);
const toSync = args.length ? args : await findAllMarkdown(CONFIG.brainPath);

console.log(`Syncing ${toSync.length} file(s)...`);

let ok = 0;
let failed = 0;
for (const rel of toSync) {
  try {
    await syncFile(rel);
    ok++;
  } catch (e) {
    console.error(`Failed: ${rel} — ${e.message}`);
    failed++;
  }
}

console.log(`\nDone: ${ok} ok, ${failed} failed.`);
process.exit(failed > 0 ? 1 : 0);
