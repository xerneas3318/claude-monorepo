import Fastify from "fastify";
import { auth, db } from "./firebase.js";
import { buildTools, executeTool } from "./tools.js";
import { runClaude } from "./claude.js";

const HOST = process.env.HOST || "127.0.0.1";
const PORT = Number(process.env.PORT || 8787);
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
if (!ANTHROPIC_API_KEY) throw new Error("ANTHROPIC_API_KEY env var is required");

const ALLOWED_UIDS = (process.env.ALLOWED_UIDS || "")
  .split(",").map((s) => s.trim()).filter(Boolean);

const app = Fastify({ logger: true });

app.addHook("onRequest", async (req, reply) => {
  if (req.routerPath === "/healthz") return;
  const header = req.headers.authorization || "";
  const match = header.match(/^Bearer (.+)$/i);
  if (!match) {
    reply.code(401).send({ error: "Missing bearer token" });
    return;
  }
  try {
    const decoded = await auth.verifyIdToken(match[1]);
    if (ALLOWED_UIDS.length && !ALLOWED_UIDS.includes(decoded.uid)) {
      reply.code(403).send({ error: "uid not allowed" });
      return;
    }
    req.firebaseUid = decoded.uid;
  } catch (err) {
    reply.code(401).send({ error: "Invalid token", detail: err.message });
  }
});

app.get("/healthz", async () => ({ ok: true }));

app.post("/talk", async (req, reply) => {
  const uid = req.firebaseUid;
  const { transcript, history } = req.body ?? {};
  const text = String(transcript ?? "").trim();
  if (!text) {
    reply.code(400).send({ error: "empty transcript" });
    return;
  }
  const priorHistory = Array.isArray(history) ? history : [];

  try {
    const { reply: text2, finalHistory, toolCalls } = await runClaude({
      apiKey: ANTHROPIC_API_KEY,
      transcript: text,
      priorHistory,
      tools: buildTools(),
      onToolCall: (name, input) => executeTool(name, input, { db, uid }),
    });
    return { reply: text2, history: finalHistory, toolCalls };
  } catch (err) {
    req.log.error({ err }, "talkToClaude failed");
    reply.code(500).send({ error: err.message || "internal error" });
  }
});

app.listen({ host: HOST, port: PORT })
  .then((addr) => app.log.info(`relay listening on ${addr}`))
  .catch((err) => { app.log.error(err); process.exit(1); });
