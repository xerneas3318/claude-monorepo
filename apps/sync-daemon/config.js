import { homedir } from "node:os";
import { join } from "node:path";

export const CONFIG = {
  serviceAccountPath: join(homedir(), ".config/brain-sync/service-account.json"),
  brainPath: process.env.BRAIN_PATH ?? join(homedir(), "Brain"),
  debounceMs: 500,
  // Firestore project ID. Set via env: FIREBASE_PROJECT_ID=your-project-id
  projectId: process.env.FIREBASE_PROJECT_ID ?? "REPLACE_WITH_FIREBASE_PROJECT_ID",
  // The Firestore subtree to read/write. Must match the iOS app's signed-in
  // Firebase UID. Override via env: BRAIN_SYNC_USER_ID="abc123..."
  userId: process.env.BRAIN_SYNC_USER_ID ?? "default",
  // Identifies which sync instance produced a write. Used as Firestore
  // `updated_by` and to skip self-writes on the Firestore -> markdown side.
  // Override per host: laptop, hetzner, etc.
  nodeId: process.env.BRAIN_SYNC_NODE_ID ?? "laptop",
  // Only .md files are synced. Hidden dirs (.git, .obsidian, .claude, .DS_Store) are ignored.
  // Files matching these patterns (relative path) are also skipped:
  ignoredPaths: [
    // empty for now — keep all .md files including archive/, history/, notes/
  ],
};
