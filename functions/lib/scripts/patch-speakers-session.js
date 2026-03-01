"use strict";
/**
 * patch-speakers-session.ts
 *
 * Sets the `sessionId` field on each speaker document so the app can match
 * speakers to session cards.
 *
 * USAGE:
 *   1. Fill in the SPEAKERS array below with the correct mapping.
 *   2. Run:
 *        cd functions
 *        npx ts-node --project tsconfig.json src/scripts/patch-speakers-session.ts
 *
 * HOW TO FIND SPEAKER IDs:
 *   - Open Firebase Console → Firestore → events/march-assembly/speakers
 *   - Copy each document ID (e.g. "rommel-dolar")
 *
 * HOW TO FIND SESSION IDs:
 *   - Open Firebase Console → Firestore → events/march-assembly/sessions
 *   - Session IDs are: main-checkin, evangelization-rally, birthdays-anniversaries, dinner-fellowship
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const admin = __importStar(require("firebase-admin"));
// Uses Application Default Credentials (firebase-admin auto-detects when
// GOOGLE_APPLICATION_CREDENTIALS env var or gcloud auth is configured).
admin.initializeApp();
const db = admin.firestore();
// ─── EDIT THIS MAPPING ────────────────────────────────────────────────────────
// Format: { eventId, speakerId (Firestore doc ID), sessionId }
const SPEAKERS = [
    // Example for march-assembly — replace speakerId with actual Firestore doc IDs:
    { eventId: "march-assembly", speakerId: "rommel-dolar", sessionId: "evangelization-rally" },
    { eventId: "march-assembly", speakerId: "mike-suela", sessionId: "birthdays-anniversaries" },
    // Add more entries as needed:
    // { eventId: "march-assembly", speakerId: "...", sessionId: "dinner-fellowship" },
];
// ─────────────────────────────────────────────────────────────────────────────
async function main() {
    for (const { eventId, speakerId, sessionId } of SPEAKERS) {
        const ref = db
            .collection("events")
            .doc(eventId)
            .collection("speakers")
            .doc(speakerId);
        const snap = await ref.get();
        if (!snap.exists) {
            console.warn(`⚠️  Speaker not found: events/${eventId}/speakers/${speakerId}`);
            continue;
        }
        await ref.update({ sessionId });
        console.log(`✅  events/${eventId}/speakers/${speakerId} → sessionId="${sessionId}"`);
    }
    console.log("Done.");
    process.exit(0);
}
main().catch((e) => {
    console.error(e);
    process.exit(1);
});
//# sourceMappingURL=patch-speakers-session.js.map