import { readFileSync } from "node:fs";
import admin from "firebase-admin";
import { CONFIG } from "../config.js";

// Credential precedence:
//   1. FIREBASE_SERVICE_ACCOUNT_JSON / GOOGLE_SERVICE_ACCOUNT_JSON
//      (raw JSON string in env, no file on disk)
//   2. GOOGLE_APPLICATION_CREDENTIALS (path to service-account.json)
//   3. CONFIG.serviceAccountPath fallback (~/.config/brain-sync/service-account.json)
const inlineJson =
  process.env.FIREBASE_SERVICE_ACCOUNT_JSON ||
  process.env.GOOGLE_SERVICE_ACCOUNT_JSON;

let serviceAccount;
if (inlineJson) {
  serviceAccount = JSON.parse(inlineJson);
} else {
  const path = process.env.GOOGLE_APPLICATION_CREDENTIALS || CONFIG.serviceAccountPath;
  serviceAccount = JSON.parse(readFileSync(path, "utf8"));
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

export const db = admin.firestore();
export const FieldValue = admin.firestore.FieldValue;
