import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

// Initialize Admin SDK once per instance.
const app = getApps().length ? getApps()[0] : initializeApp();

export const db = getFirestore(app);
