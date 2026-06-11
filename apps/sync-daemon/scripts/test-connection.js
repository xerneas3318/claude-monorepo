import { readFileSync, existsSync } from "node:fs";
import admin from "firebase-admin";
import { CONFIG } from "../config.js";

function fail(msg) {
  console.error("FAIL:", msg);
  process.exit(1);
}

function ok(msg) {
  console.log("OK:  ", msg);
}

if (!existsSync(CONFIG.serviceAccountPath)) {
  fail(`Service account not found at ${CONFIG.serviceAccountPath}`);
}
ok(`Service account file exists`);

let serviceAccount;
try {
  serviceAccount = JSON.parse(readFileSync(CONFIG.serviceAccountPath, "utf8"));
} catch (e) {
  fail(`Service account JSON is invalid: ${e.message}`);
}

if (serviceAccount.project_id !== CONFIG.projectId) {
  fail(
    `Service account project_id (${serviceAccount.project_id}) does not match CONFIG.projectId (${CONFIG.projectId})`
  );
}
ok(`Service account project_id matches: ${CONFIG.projectId}`);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
ok("Firebase Admin SDK initialized");

const db = admin.firestore();

try {
  const testRef = db.collection("_sync_test").doc("connection");
  await testRef.set({
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    message: "Connection test successful",
  });
  ok("Wrote test document to _sync_test/connection");

  const snap = await testRef.get();
  if (!snap.exists) fail("Test document write succeeded but read returned nothing");
  ok("Read test document back");

  await testRef.delete();
  ok("Deleted test document");

  console.log("\nAll checks passed. Firestore connection works.");
  process.exit(0);
} catch (e) {
  fail(`Firestore operation failed: ${e.message}`);
}
