// Parser for daily/today.md and daily/history/YYYY-MM-DD.md
//
// Recognized structure:
//   # <title>           ← H1 title (date header), one per file
//   ## <Category>       ← section header
//   - [ ] <task>        ← unchecked task
//   - [x] <task>        ← checked task
//     <indented body>   ← belongs to the task above (notes, sub-items, due
//                          dates, etc.). Carried in the `notes` field on the
//                          task and never shown in the phone's compact row.
//   <free text>         ← ignored
//
// Output: { title, tasks }
//   tasks = [{ category, text, checked, order, notes }]

const TASK_RE = /^-\s*\[( |x|X)\]\s+(.+?)\s*$/;

export function parseToday(markdown) {
  const lines = markdown.split(/\r?\n/);
  const tasks = [];
  let title = "";
  let category = "Uncategorized";
  let order = 0;
  let currentTask = null;
  const noteBuf = [];

  function flushNotes() {
    if (currentTask) {
      while (noteBuf.length && noteBuf[noteBuf.length - 1].trim() === "") noteBuf.pop();
      currentTask.notes = noteBuf.length ? noteBuf.join("\n") : "";
      noteBuf.length = 0;
      currentTask = null;
    }
  }

  for (const line of lines) {
    if (line.startsWith("# ") && !line.startsWith("## ")) {
      flushNotes();
      title = line.slice(2).trim();
      continue;
    }
    if (line.startsWith("## ")) {
      flushNotes();
      category = line.slice(3).trim();
      continue;
    }
    const m = line.match(TASK_RE);
    if (m) {
      flushNotes();
      currentTask = {
        category,
        text: m[2],
        checked: m[1].toLowerCase() === "x",
        order: order++,
        notes: "",
      };
      tasks.push(currentTask);
      continue;
    }
    if (currentTask && (line.startsWith("  ") || line.startsWith("\t"))) {
      // Strip one level of indent. Deeper nesting is preserved relatively.
      noteBuf.push(line.replace(/^( {2}|\t)/, ""));
      continue;
    }
    if (line.trim() === "" && currentTask) {
      noteBuf.push("");
      continue;
    }
    flushNotes();
  }
  flushNotes();

  return { title, tasks };
}
