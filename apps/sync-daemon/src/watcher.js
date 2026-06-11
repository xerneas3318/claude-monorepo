import chokidar from "chokidar";
import { CONFIG } from "../config.js";

// Watch the entire Brain directory using fsevents (kernel-level on macOS).
// Filter to *.md files; ignore hidden directories (.git, .obsidian, .claude).
// No polling. Debouncer coalesces rapid edits per-file.
export function watch({ onChange, onDelete }) {
  const watcher = chokidar.watch(CONFIG.brainPath, {
    persistent: true,
    ignoreInitial: false, // emit current state on startup
    usePolling: false,
    ignored: [
      /(^|[/\\])\../, // hidden files/dirs (.git, .obsidian, .DS_Store, etc.)
      ...CONFIG.ignoredPaths,
    ],
    awaitWriteFinish: {
      stabilityThreshold: 250,
      pollInterval: 50,
    },
  });

  const timers = new Map();

  function schedule(absPath, handler) {
    if (!absPath.endsWith(".md")) return;
    const rel = relFromAbs(absPath);
    clearTimeout(timers.get(rel));
    timers.set(
      rel,
      setTimeout(() => {
        timers.delete(rel);
        handler(rel).catch((e) =>
          console.error(`[sync] error for ${rel}: ${e.message}`)
        );
      }, CONFIG.debounceMs)
    );
  }

  watcher.on("add", (p) => schedule(p, onChange));
  watcher.on("change", (p) => schedule(p, onChange));
  watcher.on("unlink", (p) => schedule(p, onDelete));
  watcher.on("error", (e) => console.error("[watcher] error:", e.message));

  return watcher;
}

function relFromAbs(absPath) {
  const prefix = CONFIG.brainPath + "/";
  return absPath.startsWith(prefix) ? absPath.slice(prefix.length) : absPath;
}
