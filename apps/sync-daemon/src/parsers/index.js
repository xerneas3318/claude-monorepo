import { parseToday } from "./today.js";
import { parseFuture } from "./future.js";

// Returns { kind, title, tasks } for any markdown file.
// Files with recognized structure get task extraction.
// Everything else is preserved raw with title extraction only.
export function parseForPath(relPath, raw) {
  if (relPath === "daily/today.md" || relPath.startsWith("daily/history/")) {
    return { kind: "today", ...parseToday(raw) };
  }
  if (relPath === "daily/future.md") {
    return { kind: "future", ...parseFuture(raw) };
  }
  return { kind: "raw", title: extractTitle(raw), tasks: [] };
}

function extractTitle(raw) {
  const m = raw.match(/^#\s+(.+)/m);
  return m ? m[1].trim() : null;
}
