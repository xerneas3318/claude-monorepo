// Parser for daily/future.md
//
// Recognized structure: markdown table rows of the form
//   | YYYY-MM-DD | Category | Task |
//
// Header rows ("| Date | Category | Task |") and separator rows
// ("|------|...") are skipped. Lines outside the table are ignored.
//
// Output: { tasks }
//   tasks = [{ date, category, text, checked: false, order }]

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export function parseFuture(markdown) {
  const lines = markdown.split(/\r?\n/);
  const tasks = [];
  let order = 0;

  for (const line of lines) {
    if (!line.includes("|")) continue;
    const cells = line.split("|").map((c) => c.trim());
    // First and last entries from split("|") are typically empty (leading/trailing |)
    const inner = cells.filter((_, i) => i !== 0 && i !== cells.length - 1);
    if (inner.length !== 3) continue;
    const [date, category, task] = inner;
    if (!DATE_RE.test(date)) continue;
    if (!task) continue;
    tasks.push({
      date,
      category,
      text: task,
      checked: false,
      order: order++,
    });
  }

  return { tasks };
}
