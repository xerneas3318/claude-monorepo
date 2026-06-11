import Anthropic from "@anthropic-ai/sdk";

const MODEL = process.env.ANTHROPIC_MODEL || "claude-opus-4-7";
const MAX_TOKENS = 1024;
const MAX_TOOL_ROUNDS = 6;

const SYSTEM_PROMPT = `You are the user's personal planning assistant on their phone. Their planner lives in markdown at ~/Brain/, mirrored to Firestore. Today's tasks are in daily/today.md. Other useful files: backlog/upcoming.md (deadlines), backlog/tasks.md (unscheduled), backlog/someday.md, projects/*/overview.md, goals/this-week.md.

Use the provided tools to read and act on the planner — never invent task ids. Always call list_today before claiming what's on the list.

Style: concise, no preamble, no fluff. Two sentences max unless the user asks for more. When you check or uncheck a task, confirm in one short sentence (e.g. "Checked off the first task."). When listing tasks, group by category with short labels. If you call read_file, summarize — don't dump the whole markdown back at the user.`;

export async function runClaude({ apiKey, transcript, priorHistory, tools, onToolCall }) {
  const client = new Anthropic({ apiKey });

  const messages = [
    ...priorHistory,
    { role: "user", content: transcript },
  ];

  const toolCallsLog = [];

  for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
    const response = await client.messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: [
        { type: "text", text: SYSTEM_PROMPT, cache_control: { type: "ephemeral" } },
      ],
      tools,
      messages,
    });

    messages.push({ role: "assistant", content: response.content });

    if (response.stop_reason !== "tool_use") {
      const reply = response.content
        .filter((b) => b.type === "text")
        .map((b) => b.text)
        .join("\n")
        .trim();
      return { reply, finalHistory: messages, toolCalls: toolCallsLog };
    }

    const toolUses = response.content.filter((b) => b.type === "tool_use");
    const toolResults = [];
    for (const tu of toolUses) {
      let resultText;
      try {
        const result = await onToolCall(tu.name, tu.input ?? {});
        resultText = typeof result === "string" ? result : JSON.stringify(result);
        toolCallsLog.push({ name: tu.name, input: tu.input, ok: true });
      } catch (err) {
        resultText = `ERROR: ${err.message}`;
        toolCallsLog.push({ name: tu.name, input: tu.input, ok: false, error: err.message });
      }
      toolResults.push({
        type: "tool_result",
        tool_use_id: tu.id,
        content: resultText,
      });
    }
    messages.push({ role: "user", content: toolResults });
  }

  return {
    reply: "Stopped after too many tool calls.",
    finalHistory: messages,
    toolCalls: toolCallsLog,
  };
}
