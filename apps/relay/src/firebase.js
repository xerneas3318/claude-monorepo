import { readFileSync } from "node:fs";
import { initializeApp, cert } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!credPath) {
  throw new Error("GOOGLE_APPLICATION_CREDENTIALS env var is required");
}
const serviceAccount = JSON.parse(readFileSync(credPath, "utf8"));

initializeApp({ credential: cert(serviceAccount) });

export const auth = getAuth();
export const db = getFirestore();
