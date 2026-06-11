import { FieldValue } from "firebase-admin/firestore";

const TODAY_FILE_ID = "daily__today.md";

export function buildTools() {
  return [
    {
      name: "list_today",
      description:
        "Return today's tasks from daily/today.md ordered by document position. Each task includes id, category, text, and checked state.",
      input_schema: { type: "object", properties: {} },
    },
    {
      name: "check_task",
      description:
        "Mark a task as completed. Use the task id returned by list_today (e.g. t0003).",
      input_schema: {
        type: "object",
        properties: { task_id: { type: "string" } },
        required: ["task_id"],
      },
    },
    {
      name: "uncheck_task",
      description: "Unmark a previously completed task.",
      input_schema: {
        type: "object",
        properties: { task_id: { type: "string" } },
        required: ["task_id"],
      },
    },
    {
      name: "read_file",
      description:
        "Read the raw markdown of any synced file by its relative path (e.g. 'daily/today.md', 'backlog/upcoming.md', 'projects/ai-intern-prep/overview.md').",
      input_schema: {
        type: "object",
        properties: { path: { type: "string" } },
        required: ["path"],
      },
    },
  ];
}

export async function executeTool(name, input, { db, uid }) {
  const userRef = db.collection("users").doc(uid);

  switch (name) {
    case "list_today": {
      const snap = await userRef
        .collection("files").doc(TODAY_FILE_ID)
        .collection("tasks").orderBy("order").get();
      return snap.docs.map((d) => {
        const t = d.data();
        return { id: d.id, category: t.category, text: t.text, checked: !!t.checked };
      });
    }
    case "check_task":
    case "uncheck_task": {
      const id = String(input.task_id ?? "");
      if (!id) throw new Error("task_id is required");
      const checked = name === "check_task";
      await userRef
        .collection("files").doc(TODAY_FILE_ID)
        .collection("tasks").doc(id)
        .update({
          checked,
          updated_at: FieldValue.serverTimestamp(),
          updated_by: "claude",
        });
      return { ok: true, id, checked };
    }
    case "read_file": {
      const path = String(input.path ?? "");
      if (!path) throw new Error("path is required");
      const fileId = path.replace(/\//g, "__");
      const doc = await userRef.collection("files").doc(fileId).get();
      if (!doc.exists) return { ok: false, error: `File not found: ${path}` };
      const data = doc.data();
      return { path, title: data.title, raw: data.raw };
    }
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}
