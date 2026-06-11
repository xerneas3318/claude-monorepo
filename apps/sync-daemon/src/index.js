import { watch } from "./watcher.js";
import { syncFile, deleteFile } from "./sync.js";
import { watchFirestore } from "./firestore-watcher.js";
import { CONFIG } from "../config.js";

console.log(`[daemon] starting — node=${CONFIG.nodeId} brain=${CONFIG.brainPath} userId=${CONFIG.userId}`);

watch({ onChange: syncFile, onDelete: deleteFile });
watchFirestore();

function shutdown(signal) {
  console.log(`[daemon] received ${signal}, exiting`);
  process.exit(0);
}
process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));
