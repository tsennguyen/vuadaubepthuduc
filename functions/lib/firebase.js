"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.db = void 0;
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
// Initialize Admin SDK once per instance.
const app = (0, app_1.getApps)().length ? (0, app_1.getApps)()[0] : (0, app_1.initializeApp)();
exports.db = (0, firestore_1.getFirestore)(app);
//# sourceMappingURL=firebase.js.map